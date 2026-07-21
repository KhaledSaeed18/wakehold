import Foundation

// The lifecycle shape of every wake source: manual timer, watched process, listening port,
// wrapped command, agent lease, or calendar event. A new session type is a new case here plus
// one file in Sessions/, never a new wake code path (ADR-001).
enum SessionKind {
    case manual(until: Date?)          // nil = indefinite
    case process(pid: pid_t)
    case port(UInt16)
    case command(pid: pid_t, label: String)
    case agent(label: String)
    case calendar(eventID: String)
}

// A wake source with a lifecycle. isActive is event-driven where the platform allows it and
// polled otherwise. The controller reads it to derive the wake assertion, never the reverse.
protocol WakeSession: Identifiable {
    var id: UUID { get }
    var label: String { get }
    var kind: SessionKind { get }
    var isActive: Bool { get }
}
