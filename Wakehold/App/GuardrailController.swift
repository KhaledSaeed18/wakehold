import Foundation
import Observation
import WakeholdKit

enum GuardrailKeys {
    static let releaseOnBattery = "releaseOnBattery"
    static let releaseOnLowPowerMode = "releaseOnLowPowerMode"
    static let batteryThreshold = "batteryThreshold"
    // Not a guardrail: whether the hold keeps the screen lit. Registered to true (see WakeholdApp).
    static let keepDisplayAwake = "keepDisplayAwake"
    // Not a guardrail: whether the hold also keeps the Mac awake with the lid closed.
    static let holdWithLidClosed = "holdWithLidClosed"
}

// Applies the power preferences to the controller: watches the PowerMonitor and the preferences,
// suppresses the assertion when a guardrail says to, and sets whether the hold keeps the display
// on. It lives in the app because it reads UI preferences; the guardrail policy itself
// (PowerGuardrail) is in the kit and is unit-tested.
@MainActor
@Observable
final class GuardrailController {
    // The latest power reading, published for the Power settings tab.
    private(set) var power: PowerState
    @ObservationIgnored private let controller: WakeController
    @ObservationIgnored private let monitor: PowerMonitor
    @ObservationIgnored private var defaultsObserver: NSObjectProtocol?
    @ObservationIgnored private var started = false

    init(controller: WakeController, monitor: PowerMonitor) {
        self.controller = controller
        self.monitor = monitor
        power = monitor.state
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
        if power != monitor.state { power = monitor.state }
        let defaults = UserDefaults.standard
        controller.setKeepDisplayAwake(defaults.bool(forKey: GuardrailKeys.keepDisplayAwake))
        controller.setHoldsWithLidClosed(defaults.bool(forKey: GuardrailKeys.holdWithLidClosed))
        let threshold = defaults.integer(forKey: GuardrailKeys.batteryThreshold)
        let guardrail = PowerGuardrail(
            releaseOnBattery: defaults.bool(forKey: GuardrailKeys.releaseOnBattery),
            batteryThreshold: threshold > 0 ? threshold : nil,
            releaseOnLowPowerMode: defaults.bool(forKey: GuardrailKeys.releaseOnLowPowerMode))
        controller.setSuppressed(guardrail.suppresses(monitor.state))
    }
}
