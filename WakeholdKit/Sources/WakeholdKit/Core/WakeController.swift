import Foundation
import Observation

// The only place that decides when the Mac stays awake. The assertion is a derived value:
// awake iff any session is active. Callers mutate the session set through add/remove and let
// reconcile() settle the assertion. Nothing outside here touches the assertion or IOKit.
@MainActor
@Observable
public final class WakeController {
    public private(set) var sessions: [any WakeSession] = []

    private var assertion: PowerAssertion?
    private let assertionName = "Wakehold"
    private let log = Log.make("WakeController")

    public init() {}

    public var isAwake: Bool { sessions.contains { $0.isActive } }

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

    // Single choke point. Acquire on the first active session, release when the last one ends,
    // and refresh the human-readable reason while the assertion stays held.
    private func reconcile() {
        guard isAwake else {
            release()
            return
        }
        if assertion == nil {
            acquire()
        } else {
            assertion?.updateReason(reason)
        }
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
