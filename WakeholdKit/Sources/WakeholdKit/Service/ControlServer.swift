import Foundation
import Darwin

// The control endpoint over a Unix domain socket (ADR-011). NWListener cannot bind a UDS, so this
// uses POSIX AF_UNIX sockets directly with a DispatchSource to accept connections (ADR-018). The
// 0600 socket scopes access to the user; getpeereid is defense in depth against a same-mode peer.
public final class ControlServer {
    private let path: String
    private let router: ControlRouter
    private let queue = DispatchQueue(label: "app.wakehold.control")
    private let ownerUID = getuid()
    private let log = Log.make("ControlServer")
    private var listenFD: Int32 = -1
    private var acceptSource: DispatchSourceRead?

    @MainActor
    public init(path: String, wake: WakeController, registry: SessionRegistry) {
        self.path = path
        self.router = ControlRouter(wake: wake, registry: registry)
    }

    public func start() throws {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw WakeholdError.endpointFailed("socket") }

        unlink(path)   // clear a stale socket from a previous run
        var addr = unixSocketAddress(path: path)
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0 else {
            close(fd)
            throw WakeholdError.endpointFailed("bind")
        }
        chmod(path, 0o600)
        guard listen(fd, 8) == 0 else {
            close(fd)
            throw WakeholdError.endpointFailed("listen")
        }

        listenFD = fd
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptConnection() }
        source.setCancelHandler { close(fd) }
        acceptSource = source
        source.resume()
        log.info("control endpoint listening at \(self.path, privacy: .public)")
    }

    public func stop() {
        acceptSource?.cancel()
        acceptSource = nil
        listenFD = -1
        unlink(path)
    }

    private func acceptConnection() {
        let conn = accept(listenFD, nil, nil)
        guard conn >= 0 else { return }
        defer { close(conn) }

        var euid: uid_t = 0
        var egid: gid_t = 0
        guard getpeereid(conn, &euid, &egid) == 0, euid == ownerUID else { return }

        guard let request = readRequest(conn) else {
            writeAll(conn, HTTP.serialize(.error(400, "bad request")))
            return
        }
        // The router is main-actor isolated; the main queue is its executor. main is free while
        // clients do their socket I/O off it, so this does not deadlock.
        let response = DispatchQueue.main.sync {
            MainActor.assumeIsolated { self.router.handle(request) }
        }
        writeAll(conn, HTTP.serialize(response))
    }

    private func readRequest(_ fd: Int32) -> Request? {
        var buffer = Data()
        var chunk = [UInt8](repeating: 0, count: 4096)
        while buffer.count < 64 * 1024 {
            if let request = HTTP.parse(buffer) { return request }
            let n = read(fd, &chunk, chunk.count)
            guard n > 0 else { return HTTP.parse(buffer) }
            buffer.append(contentsOf: chunk[0..<n])
        }
        return nil
    }

    deinit {
        acceptSource?.cancel()
        unlink(path)
    }
}
