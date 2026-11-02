import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleWakehold = Self("toggleWakehold")
}

// Registers the global toggle shortcut. It runs the same toggle as a plain click on the menu-bar
// icon.
@MainActor
enum Hotkey {
    static func register(onToggle: @escaping @MainActor () -> Void) {
        KeyboardShortcuts.onKeyUp(for: .toggleWakehold) {
            onToggle()
        }
    }
}
