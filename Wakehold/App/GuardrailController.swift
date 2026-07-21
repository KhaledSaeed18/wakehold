import Foundation
import WakeholdKit

enum GuardrailKeys {
    static let releaseOnBattery = "releaseOnBattery"
    static let releaseOnLowPowerMode = "releaseOnLowPowerMode"
    static let batteryThreshold = "batteryThreshold"
}

// Applies the power guardrails: watches the PowerMonitor and the guardrail preferences and
// suppresses the controller's assertion when the policy says to. It lives in the app because it
// reads UI preferences; the policy itself (PowerGuardrail) is in the kit and is unit-tested.
@MainActor
final class GuardrailController {
    private let controller: WakeController
    private let monitor: PowerMonitor
    private var defaultsObserver: NSObjectProtocol?
    private var started = false

    init(controller: WakeController, monitor: PowerMonitor) {
        self.controller = controller
        self.monitor = monitor
    }

    func start() {
        guard !started else { return }
        started = true
        monitor.start { [weak self] in self?.evaluate() }
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluate() }
        }
        evaluate()
    }

    private func evaluate() {
        let defaults = UserDefaults.standard
        let threshold = defaults.integer(forKey: GuardrailKeys.batteryThreshold)
        let guardrail = PowerGuardrail(
            releaseOnBattery: defaults.bool(forKey: GuardrailKeys.releaseOnBattery),
            batteryThreshold: threshold > 0 ? threshold : nil,
            releaseOnLowPowerMode: defaults.bool(forKey: GuardrailKeys.releaseOnLowPowerMode))
        controller.setSuppressed(guardrail.suppresses(monitor.state))
    }
}
