import Foundation
import Observation

// The only place that decides when the Mac stays awake. The assertion is a derived value:
// awake iff any session is active and no power guardrail is suppressing. Callers mutate the
// session set through add/remove and let reconcile() settle the assertion.
@MainActor
@Observable
public final class WakeController {
    public private(set) var sessions: [any WakeSession] = []
    public private(set) var isSuppressed = false

    // Fired when the last active session ends (some-active to none-active), so the app can run a
    // post-session action. Independent of suppression: a guardrail pausing the hold is not an end.
    public var onSessionsEmptied: (@MainActor () -> Void)?

    private var assertion: PowerAssertion?
    private var wasActive = false
    private let assertionName = "Wakehold"
    private let log = Log.make("WakeController")

    public init() {}

    public var isAwake: Bool { !isSuppressed && sessions.contains { $0.isActive } }

    // Read-only view of whether the IOKit assertion is currently held. Exposed so the reconcile
    // invariant (isHoldingAssertion == isAwake) can be asserted directly in tests.
    var isHoldingAssertion: Bool { assertion != nil }

    func add(_ session: any WakeSession) {
        sessions.append(session)
        reconcile()
    }

    func remove(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        reconcile()
    }

    // Replace a session sharing this id with an updated copy (used when a session's polled
    // liveness changes), then reconcile. The array mutation notifies observers.
    func update(_ session: any WakeSession) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        sessions[index] = session
        reconcile()
    }

    // Global power-guardrail suppression: while suppressed no session holds the assertion, but the
    // sessions remain so the hold resumes when the guardrail clears (e.g. back on AC power).
    public func setSuppressed(_ suppressed: Bool) {
        guard suppressed != isSuppressed else { return }
        isSuppressed = suppressed
        reconcile()
    }

    // Single choke point. Acquire on the first active session, release when the last one ends or a
    // guardrail suppresses, refresh the reason while held, and fire the end hook on the last exit.
    private func reconcile() {
        let active = sessions.contains { $0.isActive }
        if active && !isSuppressed {
            if assertion == nil {
                acquire()
            } else {
                assertion?.updateReason(reason)
            }
        } else {
            release()
        }
        if wasActive && !active {
            onSessionsEmptied?()
        }
        wasActive = active
    }

    private func acquire() {
        do {
            assertion = try PowerAssertion.acquire(scope: .system, name: assertionName, reason: reason)
        } catch {
            log.error("failed to acquire power assertion: \(String(describing: error), privacy: .public)")
        }
    }

    private func release() {
        assertion?.release()
        assertion = nil
    }

    private var reason: String {
        let labels = sessions.filter(\.isActive).map(\.label)
        switch labels.count {
        case 0: return "no active sessions"
        case 1: return "holding 1 session: \(labels[0])"
        default: return "holding \(labels.count) sessions: \(labels.joined(separator: ", "))"
        }
    }
}
