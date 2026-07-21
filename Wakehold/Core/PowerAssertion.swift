import IOKit.pwr_mgt
import os

// The single owner of IOKit power-assertion calls; no other file imports IOKit. One instance
// holds one live assertion. deinit releases it, and the kernel drops every assertion when the
// process exits, so a leaked or crashed handle can never keep the machine awake past our life.
final class PowerAssertion {
    // System: block idle system sleep, let the display sleep. Correct for unattended work.
    // Display: also keep the screen on. Costs real power, so it is opt-in per session.
    // PreventSystemSleep is deliberately absent: AC-only, and it fights user intent (ADR-012).
    enum Scope {
        case system
        case display

        var assertionType: String {
            switch self {
            case .system: kIOPMAssertionTypePreventUserIdleSystemSleep
            case .display: kIOPMAssertionTypePreventUserIdleDisplaySleep
            }
        }
    }

    let scope: Scope
    private var id: IOPMAssertionID = 0
    private let log = Logger(subsystem: "app.wakehold.Wakehold", category: "PowerAssertion")

    private init(scope: Scope, id: IOPMAssertionID) {
        self.scope = scope
        self.id = id
    }

    // name shows in `pmset -g assertions`; reason is the human-readable "why awake" string
    // surfaced by the system. Both are set in one call so power users can see who woke the Mac.
    static func acquire(scope: Scope, name: String, reason: String) throws -> PowerAssertion {
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithDescription(
            scope.assertionType as CFString,
            name as CFString,
            nil,
            reason as CFString,
            nil,
            0,
            nil,
            &id)
        guard result == kIOReturnSuccess else {
            throw WakeholdError.assertionFailed(code: result)
        }
        return PowerAssertion(scope: scope, id: id)
    }

    // Refresh the "why awake" reason on the live assertion as the session set changes, so the
    // system's power UI stays accurate without tearing the assertion down and recreating it.
    func updateReason(_ reason: String) {
        let result = IOPMAssertionSetProperty(
            id,
            kIOPMAssertionHumanReadableReasonKey as CFString,
            reason as CFString)
        if result != kIOReturnSuccess {
            log.error("failed to update assertion reason: \(result, privacy: .public)")
        }
    }

    func release() {
        guard id != 0 else { return }
        IOPMAssertionRelease(id)
        id = 0
    }

    deinit {
        release()
    }
}
