import SwiftUI
import WakeholdKit

@main
struct WakeholdApp: App {
    @State private var controller: WakeController
    @State private var manual: ManualSessionController
    @State private var registry: SessionRegistry
    @State private var guardrails: GuardrailController
    @State private var launch = LaunchAtLogin()
    @State private var server: ControlServer?

    init() {
        let controller = WakeController()
        let monitor = PowerMonitor()
        _controller = State(initialValue: controller)
        _manual = State(initialValue: ManualSessionController(wake: controller))
        _registry = State(initialValue: SessionRegistry(wake: controller))
        _guardrails = State(initialValue: GuardrailController(controller: controller, monitor: monitor))
        _server = State(initialValue: nil)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(controller: controller, manual: manual)
        } label: {
            Image(systemName: EyeIcon.systemImageName(isAwake: controller.isAwake))
                .task { startup() }
        }

        Settings {
            SettingsView(launch: launch)
        }
    }

    @MainActor
    private func startup() {
        startEndpoint()
        guardrails.start()
        Hotkey.register(manual: manual)
    }

    // The endpoint shares the one WakeController with the menu, so sessions opened over the socket
    // appear in the UI and hold the same assertion.
    private func startEndpoint() {
        guard server == nil else { return }
        let path = WakeholdPaths.socket()
        let controlServer = ControlServer(path: path, wake: controller, registry: registry)
        do {
            try controlServer.start()
            server = controlServer
        } catch {
            Log.make("WakeholdApp").error("control endpoint failed to start: \(String(describing: error), privacy: .public)")
        }
    }
}
