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

    private func showMenu() {
        guard let button = item?.button, let menu else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
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
