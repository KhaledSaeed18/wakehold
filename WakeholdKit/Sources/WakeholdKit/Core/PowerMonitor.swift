import Foundation
import IOKit.ps

// Watches the power source and Low Power Mode and reports changes, so the app can apply the
// user's PowerGuardrail. Event-driven via a run-loop source, no polling.
@MainActor
public final class PowerMonitor {
    public private(set) var state: PowerState
    private var runLoopSource: CFRunLoopSource?
    private var powerObserver: NSObjectProtocol?
    private var onChange: (@MainActor () -> Void)?

    public init() {
        state = PowerMonitor.readState()
    }

    public func start(onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange

        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            // The source is on the main run loop, so this fires on the main actor's executor.
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.refresh() }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = source
        }

        powerObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    private func refresh() {
        state = PowerMonitor.readState()
        onChange?()
    }

    nonisolated static func readState() -> PowerState {
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
              let first = sources.first,
              let description = IOPSGetPowerSourceDescription(blob, first)?.takeUnretainedValue() as? [String: Any] else {
            return PowerState(isOnBattery: false, batteryPercent: nil, isLowPowerMode: lowPower)
        }
        let onBattery = (description[kIOPSPowerSourceStateKey as String] as? String) == (kIOPSBatteryPowerValue as String)
        var percent: Int?
        if let current = description[kIOPSCurrentCapacityKey as String] as? Int,
           let capacity = description[kIOPSMaxCapacityKey as String] as? Int, capacity > 0 {
            percent = Int((Double(current) / Double(capacity)) * 100)
        }
        return PowerState(isOnBattery: onBattery, batteryPercent: percent, isLowPowerMode: lowPower)
    }

    deinit {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        }
        if let powerObserver {
            NotificationCenter.default.removeObserver(powerObserver)
        }
    }
}
