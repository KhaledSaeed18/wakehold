import SwiftUI
import WakeholdKit

@main
struct WakeholdApp: App {
    @State private var controller: WakeController
    @State private var manual: ManualSessionController
    @State private var registry: SessionRegistry
    @State private var launch = LaunchAtLogin()
    @State private var server: ControlServer?

    init() {
        let controller = WakeController()
        _controller = State(initialValue: controller)
        _manual = State(initialValue: ManualSessionController(wake: controller))
        _registry = State(initialValue: SessionRegistry(wake: controller))
        _server = State(initialValue: nil)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(controller: controller, manual: manual)
        } label: {
            Image(systemName: EyeIcon.systemImageName(isAwake: controller.isAwake))
                .task { startEndpoint() }
        }

        Settings {
            SettingsView(launch: launch)
        }
    }

    // The endpoint shares the one WakeController with the menu, so sessions opened over the socket
    // appear in the UI and hold the same assertion.
    @MainActor
    private func startEndpoint() {
        guard server == nil, let path = Self.socketPath() else { return }
        let controlServer = ControlServer(path: path, wake: controller, registry: registry)
        do {
            try controlServer.start()
            server = controlServer
        } catch {
            Log.make("WakeholdApp").error("control endpoint failed to start: \(String(describing: error), privacy: .public)")
        }
    }

    private static func socketPath() -> String? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = base.appendingPathComponent("Wakehold", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("wakehold.sock").path
    }
}
