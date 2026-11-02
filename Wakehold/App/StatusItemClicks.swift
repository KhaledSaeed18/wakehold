import AppKit

// MenuBarExtra hangs its menu on the status item, so the system opens it on every click. To match
// the keep-awake convention (click toggles, right-click or Option-click opens the menu), this leaves
// that menu attached, so SwiftUI keeps its items current and the system places it under the icon on
// whichever display was clicked, and cancels it as it opens when the click was a plain left click.
//
// The click itself never reaches the app: the system opens the menu, and by the time tracking
// begins a quick click has already been released. A global mouse monitor sees the mouse-down a few
// milliseconds earlier, so the last one recorded tells which click opened the menu.
@MainActor
final class StatusItemClicks {
    private struct MouseDown {
        let isPlainLeft: Bool
        let uptime: TimeInterval
    }

    private var onToggle: (@MainActor () -> Void)?
    private var lastMouseDown: MouseDown?
    private var monitors: [Any] = []
    private var observer: NSObjectProtocol?

    // A menu that starts tracking longer than this after the mouse-down was opened some other way
    // (VoiceOver, the keyboard), so it is left open.
    private let clickWindow: TimeInterval = 0.5

    func start(onToggle: @escaping @MainActor () -> Void) {
        guard observer == nil else { return }
        self.onToggle = onToggle
        let record: (NSEvent) -> Void = { [weak self] event in
            let down = MouseDown(isPlainLeft: Self.isPlainLeft(event), uptime: event.timestamp)
            MainActor.assumeIsolated { self?.lastMouseDown = down }
        }
        // Global covers the menu bar when another app is active; local covers it when Wakehold is.
        monitors = [
            NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: record),
            NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
                record(event)
                return event
            },
        ].compactMap { $0 }
        // queue nil runs the handler synchronously as tracking begins, before the menu draws.
        observer = NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification, object: nil, queue: nil) { [weak self] note in
            let menu = note.object as? NSMenu
            MainActor.assumeIsolated { self?.menuBeganTracking(menu) }
        }
    }

    private func menuBeganTracking(_ menu: NSMenu?) {
        guard let menu, menu.supermenu == nil, menu === Self.statusItem()?.menu,
              let down = lastMouseDown, down.isPlainLeft,
              ProcessInfo.processInfo.systemUptime - down.uptime < clickWindow else {
            return
        }
        lastMouseDown = nil
        // Cancelling inside the notification is too early and is ignored; the next turn of the
        // main actor, which runs inside the menu's tracking loop, closes it before it draws.
        Task { @MainActor in
            menu.cancelTrackingWithoutAnimation()
        }
        onToggle?()
    }

    private nonisolated static func isPlainLeft(_ event: NSEvent) -> Bool {
        event.type == .leftMouseDown
            && event.modifierFlags.intersection([.option, .control, .command, .shift]).isEmpty
    }

    // NSStatusBarWindow is private AppKit with no public handle to the item MenuBarExtra creates.
    // Wakehold is LSUIElement and owns only this one menu, so the status-bar window carrying a menu
    // is ours. responds(to:) guards the KVC read so a renamed key fails soft instead of throwing.
    private static func statusItem() -> NSStatusItem? {
        let key = "statusItem"
        return NSApp.windows
            .filter { $0.className == "NSStatusBarWindow" && $0.responds(to: NSSelectorFromString(key)) }
            .compactMap { $0.value(forKey: key) as? NSStatusItem }
            .first { $0.menu != nil }
    }
}
