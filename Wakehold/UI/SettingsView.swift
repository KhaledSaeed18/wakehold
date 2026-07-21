import SwiftUI
import WakeholdKit

// The ⌘, preferences window. A pure observer: it reads and writes preferences, never wake state.
struct SettingsView: View {
    let launch: LaunchAtLogin
    @AppStorage("lastManualDuration") private var defaultDuration: ManualDuration = .oneHour
    @AppStorage(GuardrailKeys.releaseOnBattery) private var releaseOnBattery = false
    @AppStorage(GuardrailKeys.releaseOnLowPowerMode) private var releaseOnLowPowerMode = false
    @AppStorage(GuardrailKeys.batteryThreshold) private var batteryThreshold = 0

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { launch.isEnabled },
                    set: { launch.setEnabled($0) }
                ))

                Picker("Default duration", selection: $defaultDuration) {
                    ForEach(ManualDuration.allCases) { duration in
                        Text(duration.menuTitle).tag(duration)
                    }
                }
            }

            Section("Power guardrails") {
                Toggle("Release on battery", isOn: $releaseOnBattery)
                Toggle("Release in Low Power Mode", isOn: $releaseOnLowPowerMode)
                Stepper(
                    batteryThreshold == 0 ? "Release below battery: off" : "Release below \(batteryThreshold)%",
                    value: $batteryThreshold, in: 0...95, step: 5)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
    }
}
