import SwiftUI
import UserNotifications
import WakeholdKit

@main
struct WakeholdApp: App {
    @State private var controller: WakeController
    @State private var manual: ManualSessionController
    @State private var registry: SessionRegistry
    @State private var guardrails: GuardrailController
    @State private var clock: MenuBarClock
    @State private var apps: AppSessionController
    @State private var durations = DurationStore()
    @State private var endActions = EndActionController()
    @State private var launch = LaunchAtLogin()
    @State private var server: ControlServer?

    init() {
        // Keeping the display on is the default; UserDefaults.bool reads unset keys as false, so
        // register the true default before anything reads it.
        UserDefaults.standard.register(defaults: [GuardrailKeys.keepDisplayAwake: true])
        let controller = WakeController()
        let monitor = PowerMonitor()
        _controller = State(initialValue: controller)
        _manual = State(initialValue: ManualSessionController(wake: controller))
        _registry = State(initialValue: SessionRegistry(wake: controller))
        _guardrails = State(initialValue: GuardrailController(controller: controller, monitor: monitor))
        _clock = State(initialValue: MenuBarClock(controller: controller))
        _apps = State(initialValue: AppSessionController(wake: controller))
        _server = State(initialValue: nil)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(controller: controller, manual: manual, endActions: endActions, apps: apps, durations: durations)
        } label: {
            MenuBarLabel(controller: controller, clock: clock)
                .task { startup() }
        }

        Settings {
            SettingsView(launch: launch, durations: durations)
        }
    }

    @MainActor
    private func startup() {
        startEndpoint()
        guardrails.start()
        Hotkey.register(manual: manual, durations: durations)
        manual.onChange = { [clock] in clock.sync() }
        clock.sync()
        controller.onSessionsEmptied = { [endActions] in endActions.fire() }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
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
