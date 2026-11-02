import AppKit

// MenuBarExtra hangs its menu on the status item, so the system opens it on every click and the app
// never sees the click. To match the keep-awake convention (click toggles, right-click or
// Option-click opens the menu), this takes the menu off the status item, routes clicks to its own
// action, and pops the same SwiftUI-built menu up on demand.
@MainActor
final class StatusItemClicks: NSObject {
    private var item: NSStatusItem?
    private var menu: NSMenu?
    private var menuObservation: NSKeyValueObservation?
    private var onToggle: (@MainActor () -> Void)?
    private var attachAttempts = 0

    func start(onToggle: @escaping @MainActor () -> Void) {
        self.onToggle = onToggle
        attach()
    }

    // The scene creates the status item around the label's first render, which can land after
    // startup() runs, so look again shortly instead of giving up.
    private func attach() {
        guard item == nil else { return }
        guard let found = Self.findStatusItem() else {
            attachAttempts += 1
            guard attachAttempts < 50 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in self?.attach() }
            return
        }
        item = found
        found.button?.target = self
        found.button?.action = #selector(handleClick)
        found.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        takeMenu(from: found)
        // SwiftUI may put the menu back when the scene updates; take it again each time.
        menuObservation = found.observe(\.menu, options: [.new]) { [weak self] item, _ in
            MainActor.assumeIsolated { self?.takeMenu(from: item) }
        }
    }

    private func takeMenu(from item: NSStatusItem) {
        guard let attached = item.menu else { return }
        menu = attached
        item.menu = nil
    }

    @objc private func handleClick() {
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseUp
            || !(event?.modifierFlags.intersection([.option, .control]).isEmpty ?? true)
        if wantsMenu {
            showMenu()
        } else {
            onToggle?()
        }
    }

    // With several displays, macOS mirrors the status item onto every menu bar but keeps one real
    // button, on the active display (the one holding the key window, often Settings). Popping up
    // relative to that button lands on the wrong screen after a click on another display's copy, so
    // place the menu in screen coordinates, under the icon the pointer actually clicked.
    private func showMenu() {
        guard let button = item?.button, let menu else { return }
        menu.popUp(positioning: nil, at: Self.menuOrigin(for: button, event: NSApp.currentEvent), in: nil)
    }

    private static func menuOrigin(for button: NSStatusBarButton, event: NSEvent?) -> NSPoint {
        let mouse = NSEvent.mouseLocation
        let size = button.bounds.size
        var offset = NSPoint(x: size.width / 2, y: size.height / 2)
        if let event, event.window === button.window {
            let local = button.convert(event.locationInWindow, from: nil)
            if (0...size.width).contains(local.x), (0...size.height).contains(local.y) {
                offset = NSPoint(x: local.x, y: button.isFlipped ? size.height - local.y : local.y)
            }
        }
        // Left edge of the icon, just below the menu bar of the screen under the pointer.
        let iconBottom = mouse.y - offset.y
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
        let barBottom = screen.map { min(iconBottom, $0.visibleFrame.maxY) } ?? iconBottom
        return NSPoint(x: mouse.x - offset.x, y: barBottom - 2)
    }

    // NSStatusBarWindow is private AppKit with no public handle to the item MenuBarExtra creates.
    // Wakehold is LSUIElement and owns only this one menu, so the status-bar window carrying a menu
    // is ours. responds(to:) guards the KVC read so a renamed key fails soft instead of throwing.
    private static func findStatusItem() -> NSStatusItem? {
        let key = "statusItem"
        return NSApp.windows
            .filter { $0.className == "NSStatusBarWindow" && $0.responds(to: NSSelectorFromString(key)) }
            .compactMap { $0.value(forKey: key) as? NSStatusItem }
            .first { $0.menu != nil }
    }
}
