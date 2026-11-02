import SwiftUI
import WakeholdKit

// The ⌘, settings window. Each tab is a pure observer: it reads models and preferences and sends
// intent, never touching wake state directly.
struct SettingsView: View {
    let controller: WakeController
    let launch: LaunchAtLogin
    let durations: DurationStore
    let guardrails: GuardrailController
    let lid: ClosedLidSettings
    let integrations: IntegrationStatus

    var body: some View {
        TabView {
            GeneralSettingsTab(launch: launch)
                .tabItem { Label("General", systemImage: "gearshape") }
            DurationsSettingsTab(durations: durations)
                .tabItem { Label("Durations", systemImage: "timer") }
            PowerSettingsTab(controller: controller, guardrails: guardrails, lid: lid)
                .tabItem { Label("Power", systemImage: "bolt") }
            IntegrationsSettingsTab(integrations: integrations)
                .tabItem { Label("Integrations", systemImage: "terminal") }
            AboutSettingsTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 500, height: 500)
        .background(BringWindowToFront())
    }
}
