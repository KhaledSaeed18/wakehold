import AppKit

// MenuBarExtra opens its menu on every click and offers no click action. To match the keep-awake
// convention (click toggles, right-click or Option-click opens the menu), a local event monitor sees
// mouse-downs on the status item before SwiftUI does. A plain left click toggles and is swallowed; a
// right, Control, or Option click is rewritten into a plain left click so MenuBarExtra opens the menu.
@MainActor
final class StatusItemClicks {
    private var monitor: Any?

    func start(onToggle: @escaping @MainActor () -> Void) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            StatusItemClicks.route(event, onToggle: onToggle)
        }
    }

    // Local monitors run on the main thread, so the toggle can assume main-actor isolation.
    private nonisolated static func route(_ event: NSEvent, onToggle: @escaping @MainActor () -> Void) -> NSEvent? {
        // Wakehold is LSUIElement with one status item, so any status-bar window in this process is
        // ours. The class is private AppKit, matched by name since there is no public handle to the
        // window MenuBarExtra creates.
        guard event.window?.className == "NSStatusBarWindow" else { return event }
        let wantsMenu = event.type == .rightMouseDown
            || !event.modifierFlags.intersection([.option, .control]).isEmpty
        guard wantsMenu else {
            MainActor.assumeIsolated { onToggle() }
            return nil
        }
        return plainLeftClick(like: event) ?? event
    }

    private nonisolated static func plainLeftClick(like event: NSEvent) -> NSEvent? {
        NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: event.locationInWindow,
            modifierFlags: [],
            timestamp: event.timestamp,
            windowNumber: event.windowNumber,
            context: nil,
            eventNumber: event.eventNumber,
            clickCount: event.clickCount,
            pressure: 1
        )
    }
}
