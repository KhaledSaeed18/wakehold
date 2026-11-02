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
    let ender: SessionEnder
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        status
        if controller.isHoldingWithLidClosed {
            Text("Stays awake with the lid closed")
        }

        holding

        otherHolds

        Divider()

        Section("Keep awake for") {
            ForEach(durations.durations) { duration in
                Button(durationTitle(duration)) {
                    manual.start(label: duration.label, seconds: duration.seconds)
                }
            }
        }

        if manualSession != nil {
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

        Picker("When last session ends", selection: Binding(
            get: { endActions.armed },
            set: { endActions.arm($0) }
        )) {
            ForEach(PostSessionAction.allCases) { action in
                Text(action.menuTitle).tag(action)
            }
        }
        .pickerStyle(.menu)
        if let pending = endActions.pending {
            Button("Cancel: \(pending.menuTitle)") { endActions.cancelPending() }
        }

        Divider()

        Button("Settings…") {
            // Activate first: an app with no Dock icon is never active when its menu is used, and
            // the window would open behind the frontmost app.
            NSApp.activate()
            openWindow(id: SettingsView.windowID)
        }
        .keyboardShortcut(",")

        Button("Quit Wakehold") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func durationTitle(_ duration: WakeDuration) -> String {
        guard duration.id == durations.defaultID else { return duration.label }
        return String(localized: "\(duration.label) (default)")
    }

    // Wakehold's own sessions, each with a submenu to end it. Labels come from the session source
    // (a pid, a port, an agent's directory), so they are never treated as localization keys.
    @ViewBuilder
    private var holding: some View {
        if !controller.sessions.isEmpty {
            Section("Holding") {
                ForEach(controller.sessions, id: \.id) { session in
                    Menu {
                        Button("End") { ender.end(session) }
                    } label: {
                        Label {
                            Text(verbatim: sessionTitle(session))
                        } icon: {
                            Image(systemName: Self.symbol(for: session.kind))
                        }
                    }
                }
            }
        }
    }

    private func sessionTitle(_ session: any WakeSession) -> String {
        guard !session.isActive else { return session.label }
        return String(localized: "\(session.label) (waiting)")
    }

    static func symbol(for kind: SessionKind) -> String {
        switch kind {
        case .manual: "timer"
        case .process: "gearshape.2"
        case .port: "network"
        case .agent: "sparkle"
        case .app: "macwindow"
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
        } else if controller.isSuppressed && controller.sessions.contains(where: \.isActive) {
            Text("Paused by a battery rule")
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
