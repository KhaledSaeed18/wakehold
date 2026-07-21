import Foundation

// The lifecycle shape of every wake source: manual timer, watched process, listening port,
// agent lease, or running app. A new session type is a new case here plus one file in
// Sessions/, never a new wake code path.
public enum SessionKind {
    case manual(until: Date?)          // nil = indefinite
    case process(pid: pid_t)
    case port(UInt16)
    case agent(label: String)
    case app(bundleID: String)

    // Short stable name for the control endpoint's /status payload.
    public var name: String {
        switch self {
        case .manual: "manual"
        case .process: "process"
        case .port: "port"
        case .agent: "agent"
        case .app: "app"
        }
    }
}

// A wake source with a lifecycle. isActive is event-driven where the platform allows it and
// polled otherwise. The controller reads it to derive the wake assertion, never the reverse.
public protocol WakeSession: Identifiable {
    var id: UUID { get }
    var label: String { get }
    var kind: SessionKind { get }
    var isActive: Bool { get }
}
