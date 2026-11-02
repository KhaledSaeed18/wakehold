import KeyboardShortcuts
import SwiftUI

struct GeneralSettingsTab: View {
    let launch: LaunchAtLogin
    @AppStorage(GuardrailKeys.keepDisplayAwake) private var keepDisplayAwake = true
    @AppStorage(LaunchKeys.activateOnLaunch) private var activateOnLaunch = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { launch.isEnabled },
                    set: { launch.setEnabled($0) }
                ))
                Toggle("Activate on launch", isOn: $activateOnLaunch)
            } header: {
                Text("Startup")
            } footer: {
                Text("Activate on launch opens a hold with the default duration each time Wakehold starts.")
            }

            Section {
                KeyboardShortcuts.Recorder("Toggle shortcut", name: .toggleWakehold)
                LabeledContent("Menu-bar icon") {
                    Text("Click to toggle, right-click for the menu")
                }
            } header: {
                Text("Controls")
            } footer: {
                Text("Starts the default duration, or turns off the running one.")
            }

            Section {
                Toggle("Keep the display on", isOn: $keepDisplayAwake)
            } header: {
                Text("Display")
            } footer: {
                Text("On, the screen stays lit while a session holds. Off, the system stays awake but the display can sleep, for unattended work.")
            }

            Section("Notifications") {
                LabeledContent("End-of-session notices") {
                    Button("Open notification settings…") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                            openURL(url)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { launch.refresh() }
    }
}
