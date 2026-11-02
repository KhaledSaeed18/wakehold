import SwiftUI
import WakeholdKit

// The settings window: a sidebar of panes beside the selected one. Each pane is a pure
// observer: it reads models and preferences and sends intent, never touching wake state directly.
struct SettingsView: View {
    static let windowID = "settings"

    let controller: WakeController
    let launch: LaunchAtLogin
    let durations: DurationStore
    let guardrails: GuardrailController
    let lid: ClosedLidSettings
    let integrations: IntegrationStatus
    @AppStorage("settingsPane") private var pane: SettingsPane = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: Binding<SettingsPane?>(
                get: { pane },
                set: { if let new = $0 { pane = new } }
            )) { item in
                Label(item.title, systemImage: item.symbol)
            }
            .navigationSplitViewColumnWidth(190)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            detail
                .navigationTitle(pane.title)
        }
        // The floor that keeps every pane usable; the window resizes freely above it.
        .frame(minWidth: 680, minHeight: 460)
        .background(BringWindowToFront())
    }

    @ViewBuilder
    private var detail: some View {
        switch pane {
        case .general:
            GeneralSettingsTab(launch: launch)
        case .durations:
            DurationsSettingsTab(durations: durations)
        case .power:
            PowerSettingsTab(controller: controller, guardrails: guardrails, lid: lid)
        case .integrations:
            IntegrationsSettingsTab(integrations: integrations)
        case .about:
            AboutSettingsTab()
        }
    }

    // The opening size: roomy on a normal display, capped to the screen it opens on so it still
    // fits a small one. Every pane is a scrolling form, so a capped height still reaches every row.
    static var defaultSize: CGSize {
        let visible = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1280, height: 800)
        return CGSize(width: min(820, visible.width - 80), height: min(680, visible.height - 100))
    }
}
