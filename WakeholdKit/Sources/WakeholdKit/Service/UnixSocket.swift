import Foundation
import Darwin

// Shared POSIX helpers for the control endpoint's Unix domain socket, used by both the server
// (bind) and the client (connect).

// Fill a sockaddr_un for a filesystem socket path.
func unixSocketAddress(path: String) -> sockaddr_un {
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let capacity = MemoryLayout.size(ofValue: addr.sun_path)
    path.withCString { cstr in
        withUnsafeMutablePointer(to: &addr.sun_path) {
            $0.withMemoryRebound(to: CChar.self, capacity: capacity) {
                _ = strncpy($0, cstr, capacity - 1)
            }
        }
    }
    return addr
}

// Write every byte to the fd, tolerating partial writes.
func writeAll(_ fd: Int32, _ data: Data) {
    data.withUnsafeBytes { raw in
        guard var pointer = raw.baseAddress else { return }
        var remaining = raw.count
        while remaining > 0 {
            let n = Darwin.write(fd, pointer, remaining)
            guard n > 0 else { break }
            pointer = pointer.advanced(by: n)
            remaining -= n
        }
    }
}

// Read from the fd until EOF.
func readToEnd(_ fd: Int32) -> Data {
    var data = Data()
    var chunk = [UInt8](repeating: 0, count: 4096)
    while true {
        let n = read(fd, &chunk, chunk.count)
        guard n > 0 else { break }
        data.append(contentsOf: chunk[0..<n])
    }
    return data
}
