import AppKit
import SwiftUI

// Wakehold has no Dock presence, so it is never the active app when the menu opens a window, and
// macOS leaves that window behind whatever the user is working in. Placed in a window's content,
// this activates the app and brings the window forward each time the view lands in it.
struct BringWindowToFront: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        FrontingView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class FrontingView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
        }
    }
}
