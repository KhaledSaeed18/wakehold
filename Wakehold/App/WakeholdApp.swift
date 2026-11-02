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
    @State private var inspector = AssertionInspector()
    @State private var clicks = StatusItemClicks()
    @State private var lidSettings = ClosedLidSettings()
    @State private var integrations = IntegrationStatus()
    @State private var lidHold: ClosedLidHold
    @State private var terminationSignal: DispatchSourceSignal?
    @State private var server: ControlServer?

    init() {
        // Keeping the display on is the default; UserDefaults.bool reads unset keys as false, so
        // register the true default before anything reads it.
        UserDefaults.standard.register(defaults: [GuardrailKeys.keepDisplayAwake: true])
        let lidHold = ClosedLidHold()
        let controller = WakeController(lid: lidHold)
        _lidHold = State(initialValue: lidHold)
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
            MenuBarView(
                controller: controller, manual: manual, endActions: endActions, apps: apps,
                durations: durations, inspector: inspector,
                ender: SessionEnder(manual: manual, apps: apps, registry: registry))
        } label: {
            MenuBarLabel(controller: controller, clock: clock)
                .task { startup() }
        }

        // A plain Window rather than the Settings scene: Settings windows are fixed-size with the
        // minimize and zoom buttons greyed out, and SwiftUI strips any resizable style added to them.
        Window("Wakehold Settings", id: SettingsView.windowID) {
            SettingsView(
                controller: controller, launch: launch, durations: durations, guardrails: guardrails,
                lid: lidSettings, integrations: integrations)
        }
        .defaultSize(SettingsView.defaultSize)
        .windowResizability(.contentMinSize)
    }

    @MainActor
    private func startup() {
        startEndpoint()
        // Before guardrails.start() applies the lid preference, so a leftover from a crash is cleared
        // first on the same serial queue.
        lidHold.clearStaleHold()
        releaseLidHoldOnQuit()
        guardrails.start()
        inspector.start()
        Hotkey.register(onToggle: toggleDefault)
        clicks.start(onToggle: toggleDefault)
        manual.onChange = { [clock] in clock.sync() }
        clock.sync()
        controller.onSessionsEmptied = { [endActions] in endActions.fire() }
        controller.onSessionsResumed = { [endActions] in endActions.cancelPending() }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
        activateOnLaunchIfEnabled()
    }

    @MainActor
    private func toggleDefault() {
        let duration = durations.defaultDuration
        manual.toggle(label: duration.label, seconds: duration.seconds)
    }

    // Sleep stays off after the process ends unless it is turned back on, so release it on a normal
    // quit, and route SIGTERM (kill, pkill) through the same quit path instead of dying outright.
    @MainActor
    private func releaseLidHoldOnQuit() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [lidHold] _ in
            MainActor.assumeIsolated { lidHold.releaseNow() }
        }
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { NSApplication.shared.terminate(nil) }
        source.resume()
        terminationSignal = source
    }

    // Activate on launch: open the default-duration hold as the app starts, the same as picking the
    // default from the menu. Runs last in startup() so guardrails.start() can immediately suppress
    // it on battery, and so onChange is already wired to refresh the menu-bar countdown.
    @MainActor
    private func activateOnLaunchIfEnabled() {
        guard UserDefaults.standard.bool(forKey: LaunchKeys.activateOnLaunch) else { return }
        let duration = durations.defaultDuration
        manual.start(label: duration.label, seconds: duration.seconds)
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
