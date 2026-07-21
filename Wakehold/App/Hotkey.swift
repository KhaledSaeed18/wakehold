import Foundation
import KeyboardShortcuts
import WakeholdKit

extension KeyboardShortcuts.Name {
    static let toggleWakehold = Self("toggleWakehold")
}

// Registers the global toggle shortcut. It mirrors the menu: stop the running manual session, or
// start the last-used duration.
@MainActor
enum Hotkey {
    static func register(manual: ManualSessionController) {
        KeyboardShortcuts.onKeyUp(for: .toggleWakehold) {
            if manual.isRunning {
                manual.stop()
            } else {
                let stored = UserDefaults.standard.string(forKey: "lastManualDuration")
                manual.start(stored.flatMap(ManualDuration.init(rawValue:)) ?? .oneHour)
            }
        }
    }
}
