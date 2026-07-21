import Foundation
import KeyboardShortcuts
import WakeholdKit

extension KeyboardShortcuts.Name {
    static let toggleWakehold = Self("toggleWakehold")
}

// Registers the global toggle shortcut. It mirrors the menu: stop the running manual session, or
// start the default duration.
@MainActor
enum Hotkey {
    static func register(manual: ManualSessionController, durations: DurationStore) {
        KeyboardShortcuts.onKeyUp(for: .toggleWakehold) {
            if manual.isRunning {
                manual.stop()
            } else {
                let duration = durations.defaultDuration
                manual.start(label: duration.label, seconds: duration.seconds)
            }
        }
    }
}
