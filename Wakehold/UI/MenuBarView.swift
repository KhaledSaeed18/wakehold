import SwiftUI
import WakeholdKit

// Contents of the menu-bar dropdown. A pure observer of the controller: it reads state and sends
// intent, never touching the assertion or IOKit. Rendered in the default menu style, so these
// are menu items, not a laid-out panel.
struct MenuBarView: View {
    let controller: WakeController
    let manual: ManualSessionController
    let endActions: EndActionController
    let apps: AppSessionController
    @AppStorage("lastManualDuration") private var lastDuration: ManualDuration = .oneHour

    var body: some View {
        status

        Divider()

        ForEach(ManualDuration.allCases) { duration in
            Button(duration.menuTitle) {
                lastDuration = duration
                manual.start(duration)
            }
        }

        if controller.isAwake {
            Button("Turn off") { manual.stop() }
        }

        Divider()

        Menu("While an app runs") {
            ForEach(apps.runningApps()) { app in
                Toggle(app.name, isOn: Binding(
                    get: { apps.watchedBundleIDs.contains(app.bundleID) },
                    set: { _ in apps.toggle(bundleID: app.bundleID, name: app.name) }
                ))
            }
        }

        Menu("When last session ends") {
            ForEach(PostSessionAction.allCases) { action in
                Button(action.menuTitle) { endActions.arm(action) }
            }
        }
        endActionStatus

        Divider()

        SettingsLink {
            Text("Settings…")
        }

        Button("Quit Wakehold") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    @ViewBuilder
    private var endActionStatus: some View {
        if let pending = endActions.pending {
            Button("Cancel: \(pending.menuTitle)") { endActions.cancelPending() }
        } else if endActions.armed != .none {
            Text("When done: \(endActions.armed.menuTitle)")
        }
    }

    @ViewBuilder
    private var status: some View {
        if let range = countdownRange {
            // A Date-anchored, self-updating countdown: SwiftUI recomputes remaining each tick, so
            // there is no drifting counter to trust.
            Text(timerInterval: range, countsDown: true)
        } else if controller.isAwake {
            Text("Awake")
        } else {
            Text("Nothing's keeping you awake.")
        }
    }

    private var manualSession: ManualSession? {
        controller.sessions.compactMap { $0 as? ManualSession }.first
    }

    private var countdownRange: ClosedRange<Date>? {
        guard let session = manualSession, let until = session.until, Date.now < until else {
            return nil
        }
        return session.startedAt...until
    }
}
