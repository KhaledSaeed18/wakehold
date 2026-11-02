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
        .frame(width: Self.size.width, height: Self.size.height)
        .background(BringWindowToFront())
    }

    // Roomy on a normal display, capped to the screen it opens on so it still fits a small one.
    // Every tab is a scrolling form, so a capped height still reaches every row.
    private static var size: CGSize {
        let visible = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1280, height: 800)
        return CGSize(width: min(640, visible.width - 80), height: min(680, visible.height - 100))
    }
}
