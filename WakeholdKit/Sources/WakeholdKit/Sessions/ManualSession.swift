import Foundation

// The classic keep-awake baseline: hold for a fixed number of seconds or indefinitely. A value
// type; expiry is driven by ManualSessionController. Label and duration come from the app's
// duration list, so user-created custom durations need no change here.
public struct ManualSession: WakeSession {
    public let id = UUID()
    public let label: String
    public let startedAt: Date
    public let until: Date?              // nil = indefinite

    public init(label: String, seconds: TimeInterval?, now: Date = .now) {
        self.label = label
        self.startedAt = now
        self.until = seconds.map { now.addingTimeInterval($0) }
    }

    // Test seam: craft a session with an explicit target date.
    init(label: String, startedAt: Date = .now, until: Date?) {
        self.label = label
        self.startedAt = startedAt
        self.until = until
    }

    public var kind: SessionKind { .manual(until: until) }

    // Wall clock is the source of truth: a timed session is active only while now is before the
    // target, so a late or imprecise expiry timer can never hold the Mac awake past the target.
    public var isActive: Bool {
        guard let until else { return true }
        return Date.now < until
    }
}
