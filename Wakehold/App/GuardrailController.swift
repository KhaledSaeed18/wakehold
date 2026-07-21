import Foundation
import WakeholdKit

enum GuardrailKeys {
    static let releaseOnBattery = "releaseOnBattery"
    static let releaseOnLowPowerMode = "releaseOnLowPowerMode"
    static let batteryThreshold = "batteryThreshold"
    // Not a guardrail: whether the hold keeps the screen lit. Registered to true (see WakeholdApp).
    static let keepDisplayAwake = "keepDisplayAwake"
}

// Applies the power preferences to the controller: watches the PowerMonitor and the preferences,
// suppresses the assertion when a guardrail says to, and sets whether the hold keeps the display
// on. It lives in the app because it reads UI preferences; the guardrail policy itself
// (PowerGuardrail) is in the kit and is unit-tested.
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
        controller.setKeepDisplayAwake(defaults.bool(forKey: GuardrailKeys.keepDisplayAwake))
        let threshold = defaults.integer(forKey: GuardrailKeys.batteryThreshold)
        let guardrail = PowerGuardrail(
            releaseOnBattery: defaults.bool(forKey: GuardrailKeys.releaseOnBattery),
            batteryThreshold: threshold > 0 ? threshold : nil,
            releaseOnLowPowerMode: defaults.bool(forKey: GuardrailKeys.releaseOnLowPowerMode))
        controller.setSuppressed(guardrail.suppresses(monitor.state))
    }
}
