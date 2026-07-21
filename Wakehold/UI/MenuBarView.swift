import SwiftUI

// Contents of the menu-bar dropdown. A pure observer of the controller: it reads state and sends
// intent, never touching the assertion or IOKit. Rendered in the default menu style, so these
// are menu items, not a laid-out panel.
struct MenuBarView: View {
    let controller: WakeController
    let manual: ManualSessionController

    var body: some View {
        status

        Divider()

        ForEach(ManualDuration.allCases) { duration in
            Button(duration.menuTitle) { manual.start(duration) }
        }

        if controller.isAwake {
            Button("Turn off") { manual.stop() }
        }

        Divider()

        Button("Quit Wakehold") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
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
