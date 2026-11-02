import SwiftUI
import WakeholdKit

struct PowerSettingsTab: View {
    let controller: WakeController
    let guardrails: GuardrailController
    let lid: ClosedLidSettings
    @AppStorage(GuardrailKeys.releaseOnBattery) private var releaseOnBattery = false
    @AppStorage(GuardrailKeys.releaseOnLowPowerMode) private var releaseOnLowPowerMode = false
    @AppStorage(GuardrailKeys.batteryThreshold) private var batteryThreshold = 0

    var body: some View {
        Form {
            Section("Now") {
                LabeledContent("Power source") {
                    Text(guardrails.power.isOnBattery ? "Battery" : "Power adapter")
                }
                if let percent = guardrails.power.batteryPercent {
                    LabeledContent("Battery") {
                        Text(verbatim: "\(percent)%").monospacedDigit()
                    }
                }
                LabeledContent("Low Power Mode") {
                    Text(guardrails.power.isLowPowerMode ? "On" : "Off")
                }
                LabeledContent("Hold") {
                    holdStatus
                }
            }

            Section {
                Toggle("Release on battery", isOn: $releaseOnBattery)
                Toggle("Release below a battery level", isOn: Binding(
                    get: { batteryThreshold > 0 },
                    set: { batteryThreshold = $0 ? 20 : 0 }
                ))
                if batteryThreshold > 0 {
                    thresholdSlider
                }
                Toggle("Release in Low Power Mode", isOn: $releaseOnLowPowerMode)
            } header: {
                Text("Battery rules")
            } footer: {
                Text("A rule pauses the hold without ending sessions; the hold resumes when the rule clears.")
            }

            ClosedLidSection(lid: lid)
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var holdStatus: some View {
        if controller.isSuppressed {
            Text("Paused by a battery rule")
        } else if controller.isAwake {
            Text("Holding")
        } else {
            Text("Idle")
        }
    }

    private var thresholdSlider: some View {
        HStack {
            Slider(value: Binding(
                get: { Double(batteryThreshold) },
                set: { batteryThreshold = Int($0.rounded()) }
            ), in: 5...90, step: 5)
            Text(verbatim: "\(batteryThreshold)%")
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
    }
}
