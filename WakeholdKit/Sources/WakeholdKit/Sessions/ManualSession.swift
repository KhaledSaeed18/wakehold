import Foundation

// The classic keep-awake baseline: hold for a fixed duration or indefinitely. A value type,
// because a manual session is just its target date; expiry is driven by ManualSessionController.
public struct ManualSession: WakeSession {
    public let id = UUID()
    public let duration: ManualDuration
    public let startedAt: Date
    public let until: Date?              // nil = indefinite

    init(duration: ManualDuration, now: Date = .now) {
        self.duration = duration
        self.startedAt = now
        self.until = duration.interval.map { now.addingTimeInterval($0) }
    }

    // Craft a session with an explicit target, used by tests to exercise near-instant expiry.
    init(duration: ManualDuration, startedAt: Date = .now, until: Date?) {
        self.duration = duration
        self.startedAt = startedAt
        self.until = until
    }

    public var kind: SessionKind { .manual(until: until) }
    public var label: String { duration.label }

    // Wall clock is the source of truth: a timed session is active only while now is before the
    // target, so a late or imprecise expiry timer can never hold the Mac awake past the target.
    public var isActive: Bool {
        guard let until else { return true }
        return Date.now < until
    }
}

// The fixed choices offered in the menu. interval is nil for the indefinite case.
public enum ManualDuration: String, CaseIterable, Identifiable, Equatable {
    case oneHour
    case twoHours
    case threeHours
    case indefinite

    public var id: Self { self }

    public var interval: TimeInterval? {
        switch self {
        case .oneHour: 3600
        case .twoHours: 7200
        case .threeHours: 10800
        case .indefinite: nil
        }
    }

    // Terse label for the session and the pmset reason (BRAND: session labels render in mono).
    public var label: String {
        switch self {
        case .oneHour: "1h"
        case .twoHours: "2h"
        case .threeHours: "3h"
        case .indefinite: "∞"
        }
    }

    // Text for the menu button.
    public var menuTitle: String {
        switch self {
        case .oneHour: "1 hour"
        case .twoHours: "2 hours"
        case .threeHours: "3 hours"
        case .indefinite: "Indefinite"
        }
    }
}
