import AppKit
import SwiftUI
import Testing
import WakeholdKit
@testable import Wakehold

// Renders each settings tab to PNG for visual review. Opt-in: runs only when
// WAKEHOLD_SNAPSHOT_DIR is set (pass TEST_RUNNER_WAKEHOLD_SNAPSHOT_DIR to xcodebuild), so the normal
// suite writes nothing.
@MainActor
struct SettingsSnapshotTests {
    private static let directory = ProcessInfo.processInfo.environment["WAKEHOLD_SNAPSHOT_DIR"]

    @Test(.enabled(if: directory != nil))
    func renderEveryTab() throws {
        let directory = try #require(Self.directory)
        let controller = WakeController()
        let defaults = try #require(UserDefaults(suiteName: "wakehold-snapshot-\(UUID().uuidString)"))
        let tabs: [(String, AnyView)] = [
            ("general", AnyView(GeneralSettingsTab(launch: LaunchAtLogin()))),
            ("durations", AnyView(DurationsSettingsTab(durations: DurationStore(defaults: defaults)))),
            ("power", AnyView(PowerSettingsTab(
                controller: controller,
                guardrails: GuardrailController(controller: controller, monitor: PowerMonitor()),
                lid: ClosedLidSettings()))),
            ("integrations", AnyView(IntegrationsSettingsTab(integrations: IntegrationStatus()))),
            ("about", AnyView(AboutSettingsTab())),
        ]
        for (name, view) in tabs {
            for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                let suffix = appearance == .aqua ? "light" : "dark"
                try render(view, appearance: appearance, to: "\(directory)/\(name)-\(suffix).png")
            }
        }
    }

    private func render(_ view: AnyView, appearance: NSAppearance.Name, to path: String) throws {
        let size = NSSize(width: 640, height: 680)
        // cacheDisplay captures the view, not the window, so paint the window background in.
        let host = NSHostingView(rootView: view
            .frame(width: size.width, height: size.height)
            .background(Color(nsColor: .windowBackgroundColor)))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.contentView = host
        // Let .task and .onAppear work settle before capturing.
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        host.layoutSubtreeIfNeeded()
        let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        let data = try #require(rep.representation(using: .png, properties: [:]))
        try data.write(to: URL(fileURLWithPath: path))
    }
}
