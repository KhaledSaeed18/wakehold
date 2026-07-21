import Foundation

// Opened over the control endpoint by an agent CLI (Claude Code and friends). A lease: it stays
// active until the registry expires it after a TTL of silence, so a crashed client that never
// says goodbye cannot hold the Mac awake forever. Renewal resets that clock.
public struct AgentSession: WakeSession {
    public let id = UUID()
    public let label: String

    public var kind: SessionKind { .agent(label: label) }
    public var isActive: Bool { true }
}
