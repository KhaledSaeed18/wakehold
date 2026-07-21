import SwiftUI

// Contents of the menu-bar dropdown. A pure observer of the controller: it reads state and
// sends intent, never touching the assertion or IOKit. Rendered in the default menu style, so
// these are menu items, not a laid-out panel.
struct MenuBarView: View {
    let controller: WakeController

    var body: some View {
        Text(statusText)

        Divider()

        Button("Quit Wakehold") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private var statusText: String {
        controller.isAwake ? "Awake" : "Nothing's keeping you awake."
    }
}
