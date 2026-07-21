import SwiftUI

@main
struct WakeholdApp: App {
    var body: some Scene {
        MenuBarExtra("Wakehold", systemImage: "eye") {
            Button("Quit Wakehold") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
