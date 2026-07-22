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
    let durations: DurationStore
    let inspector: AssertionInspector

    var body: some View {
        status

        otherHolds

        Divider()

        ForEach(durations.durations) { duration in
            Button(duration.label) { manual.start(label: duration.label, seconds: duration.seconds) }
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

    // Every other process holding the Mac awake, so the menu answers "why won't it sleep" for the
    // whole machine, not just Wakehold's own holds. Informational rows, shown only when present.
    @ViewBuilder
    private var otherHolds: some View {
        if !inspector.holds.isEmpty {
            Section("Also keeping it awake") {
                ForEach(inspector.holds) { hold in
                    holdRow(hold)
                }
            }
        }
    }

    // Process name over its assertion reason, when the process gave one. Names and reasons come from
    // the system verbatim, so they are never treated as localization keys.
    @ViewBuilder
    private func holdRow(_ hold: ProcessHold) -> some View {
        let icon = hold.keepsDisplayAwake ? "sun.max" : "cpu"
        if let reason = hold.displayReason {
            Label {
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: hold.processName)
                    Text(verbatim: reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } icon: {
                Image(systemName: icon)
            }
        } else {
            Label(hold.processName, systemImage: icon)
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
