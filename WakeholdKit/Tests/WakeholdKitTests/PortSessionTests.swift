import Testing
import Foundation
import Darwin
@testable import WakeholdKit

@MainActor
struct PortSessionTests {
    @Test func detectsListeningThenClosed() throws {
        let (fd, port) = try openLocalListener()
        #expect(isPortListening(port))
        close(fd)
        #expect(!isPortListening(port))
    }

    @Test func holdsWhilePortListensThenReleasesWhenClosed() async throws {
        let (fd, port) = try openLocalListener()
        var closed = false
        defer { if !closed { close(fd) } }

        let wake = WakeController()
        let registry = SessionRegistry(wake: wake, portPollInterval: 0.2)
        _ = registry.startPort(port, label: ":\(port)")
        #expect(wake.isAwake)
        #expect(wake.isHoldingAssertion)

        close(fd)
        closed = true
        try await pollUntil(timeout: 5) { !wake.isAwake }
        #expect(!wake.isAwake)
    }
}

// Opens a TCP listener on an ephemeral 127.0.0.1 port and returns its fd and the assigned port.
private func openLocalListener() throws -> (fd: Int32, port: UInt16) {
    let fd = socket(AF_INET, SOCK_STREAM, 0)
    guard fd >= 0 else { throw POSIXError(.EADDRNOTAVAIL) }

    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_addr.s_addr = inet_addr("127.0.0.1")
    addr.sin_port = 0

    let bound = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard bound == 0, listen(fd, 1) == 0 else {
        close(fd)
        throw POSIXError(.EADDRINUSE)
    }

    var assigned = sockaddr_in()
    var len = socklen_t(MemoryLayout<sockaddr_in>.size)
    _ = withUnsafeMutablePointer(to: &assigned) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            getsockname(fd, $0, &len)
        }
    }
    return (fd, UInt16(bigEndian: assigned.sin_port))
}
