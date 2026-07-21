import SwiftUI
import WakeholdKit

// The ⌘, preferences window, tabbed. Pure observers: they read and write preferences, never wake
// state.
struct SettingsView: View {
    let launch: LaunchAtLogin
    let durations: DurationStore

    var body: some View {
        TabView {
            GeneralTab(launch: launch)
                .tabItem { Label("General", systemImage: "gearshape") }
            DurationsTab(durations: durations)
                .tabItem { Label("Durations", systemImage: "timer") }
            BatteryTab()
                .tabItem { Label("Battery", systemImage: "battery.100") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 440, height: 340)
    }
}

private struct GeneralTab: View {
    let launch: LaunchAtLogin
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: Binding(
                get: { launch.isEnabled },
                set: { launch.setEnabled($0) }
            ))
            Button("Open notification settings…") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                    openURL(url)
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct DurationsTab: View {
    let durations: DurationStore
    @State private var hours = 1
    @State private var minutes = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            List {
                ForEach(durations.durations) { duration in
                    HStack {
                        Text(duration.label)
                        if duration.id == durations.defaultID {
                            Text("default").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if duration.id != durations.defaultID {
                            Button("Set default") { durations.setDefault(duration.id) }
                                .buttonStyle(.link)
                        }
                        Button {
                            durations.remove(duration.id)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            HStack {
                Text("Add a duration")
                Spacer()
                Stepper("\(hours) h", value: $hours, in: 0...23)
                Stepper("\(minutes) m", value: $minutes, in: 0...59, step: 5)
                Button("Add") {
                    durations.add(seconds: TimeInterval(hours * 3600 + minutes * 60))
                }
                .disabled(hours == 0 && minutes == 0)
            }
        }
        .padding()
    }
}

private struct BatteryTab: View {
    @AppStorage(GuardrailKeys.releaseOnBattery) private var releaseOnBattery = false
    @AppStorage(GuardrailKeys.releaseOnLowPowerMode) private var releaseOnLowPowerMode = false
    @AppStorage(GuardrailKeys.batteryThreshold) private var batteryThreshold = 0

    var body: some View {
        Form {
            Toggle("Release on battery", isOn: $releaseOnBattery)

            Toggle("Release below a battery level", isOn: Binding(
                get: { batteryThreshold > 0 },
                set: { batteryThreshold = $0 ? 20 : 0 }
            ))
            if batteryThreshold > 0 {
                HStack {
                    Slider(value: Binding(
                        get: { Double(batteryThreshold) },
                        set: { batteryThreshold = Int($0.rounded()) }
                    ), in: 5...90, step: 5)
                    Text("\(batteryThreshold)%").monospacedDigit().frame(width: 44, alignment: .trailing)
                }
            }

            Toggle("Release in Low Power Mode", isOn: $releaseOnLowPowerMode)
        }
        .formStyle(.grouped)
    }
}

private struct AboutTab: View {
    private var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String).map { "Version \($0)" } ?? ""
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 56, height: 56)
            Text("Wakehold").font(.title2)
            Text(version).foregroundStyle(.secondary)
            if let url = URL(string: "https://github.com/KhaledSaeed18/wakehold") {
                Link("github.com/KhaledSaeed18/wakehold", destination: url)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
