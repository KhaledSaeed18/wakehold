import Testing
@testable import WakeholdKit

struct PowerGuardrailTests {
    @Test func defaultGuardrailNeverSuppresses() {
        let guardrail = PowerGuardrail()
        #expect(!guardrail.suppresses(PowerState(isOnBattery: true, batteryPercent: 5, isLowPowerMode: true)))
    }

    @Test func releaseOnBatterySuppressesOnlyWhenUnplugged() {
        let guardrail = PowerGuardrail(releaseOnBattery: true)
        #expect(guardrail.suppresses(PowerState(isOnBattery: true, batteryPercent: 80, isLowPowerMode: false)))
        #expect(!guardrail.suppresses(PowerState(isOnBattery: false, batteryPercent: 80, isLowPowerMode: false)))
    }

    @Test func thresholdSuppressesBelowButNotAt() {
        let guardrail = PowerGuardrail(batteryThreshold: 30)
        #expect(guardrail.suppresses(PowerState(isOnBattery: true, batteryPercent: 29, isLowPowerMode: false)))
        #expect(!guardrail.suppresses(PowerState(isOnBattery: true, batteryPercent: 30, isLowPowerMode: false)))
    }

    @Test func lowPowerModeSuppressesEvenOnAC() {
        let guardrail = PowerGuardrail(releaseOnLowPowerMode: true)
        #expect(guardrail.suppresses(PowerState(isOnBattery: false, batteryPercent: 90, isLowPowerMode: true)))
    }

    // Reads the real machine's power state; just checks it returns something sane.
    @Test func monitorReadsStateWithoutCrashing() {
        let state = PowerMonitor.readState()
        if let percent = state.batteryPercent {
            #expect((0...100).contains(percent))
        }
    }
}
