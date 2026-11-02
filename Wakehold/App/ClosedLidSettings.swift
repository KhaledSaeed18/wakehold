import Foundation
import WakeholdKit

// Settings-side state for the closed-lid hold: whether the one-time setup is in place, and the
// install and remove actions. Each check and the admin prompt block, so they run on a global
// queue rather than the cooperative pool, and hop back to the main actor to publish.
@MainActor
@Observable
final class ClosedLidSettings {
    // nil until the first check finishes.
    private(set) var isAuthorized: Bool?
    private(set) var isWorking = false
    private(set) var didFail = false

    func refresh() {
        DispatchQueue.global(qos: .userInitiated).async {
            let authorized = ClosedLidHold.isAuthorized()
            DispatchQueue.main.async { MainActor.assumeIsolated { self.publish(authorized: authorized) } }
        }
    }

    func install() {
        perform { try ClosedLidSetup.install() }
    }

    func remove() {
        perform { try ClosedLidSetup.remove() }
    }

    private func perform(_ step: @escaping @Sendable () throws -> Void) {
        guard !isWorking else { return }
        isWorking = true
        didFail = false
        DispatchQueue.global(qos: .userInitiated).async {
            var failed = false
            do {
                try step()
            } catch ClosedLidSetup.SetupError.canceled {
                // The user dismissed the admin prompt; nothing to report.
            } catch {
                failed = true
            }
            let authorized = ClosedLidHold.isAuthorized()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.isWorking = false
                    self.didFail = failed
                    self.publish(authorized: authorized)
                }
            }
        }
    }

    // Without the rule the hold cannot apply, so the preference goes off with it rather than
    // showing an on switch that does nothing.
    private func publish(authorized: Bool) {
        isAuthorized = authorized
        if !authorized {
            UserDefaults.standard.set(false, forKey: GuardrailKeys.holdWithLidClosed)
        }
    }
}
