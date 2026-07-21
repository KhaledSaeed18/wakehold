import Foundation
import Darwin

// Awake while something listens on 127.0.0.1:port. Liveness is polled (there is no clean event
// for "a port opened or closed"), so isActive reflects the last poll. Best-effort: a root-owned
// listener still answers a connect, but the poll cannot see who owns it.
public struct PortSession: WakeSession {
    public let id = UUID()
    public let port: UInt16
    public let label: String
    public var isListening: Bool

    public var kind: SessionKind { .port(port) }
    public var isActive: Bool { isListening }
}

// Whether a TCP listener currently accepts connections on 127.0.0.1:port. A localhost connect
// returns immediately (accepted or refused), so this does not block on the network.
func isPortListening(_ port: UInt16) -> Bool {
    let fd = socket(AF_INET, SOCK_STREAM, 0)
    guard fd >= 0 else { return false }
    defer { close(fd) }

    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = port.bigEndian
    addr.sin_addr.s_addr = inet_addr("127.0.0.1")

    let connected = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    return connected == 0
}
