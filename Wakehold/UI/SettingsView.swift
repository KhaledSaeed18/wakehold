import SwiftUI
import WakeholdKit

// The ⌘, preferences window. A pure observer: it reads and writes preferences, never wake state.
struct SettingsView: View {
    let launch: LaunchAtLogin
    @AppStorage("lastManualDuration") private var defaultDuration: ManualDuration = .oneHour

    var body: some View {
        Form {
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
        .formStyle(.grouped)
        .frame(width: 360)
    }
}
