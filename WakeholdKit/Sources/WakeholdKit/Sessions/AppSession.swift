import Foundation

// Awake while a GUI app (by bundle id) is running. Liveness comes from NSWorkspace launch and
// terminate notifications, observed in the app layer (AppKit) which flips isRunning here. Kept
// free of AppKit so the kit and the CLI never link it.
public struct AppSession: WakeSession {
    public let id = UUID()
    public let bundleID: String
    public let label: String
    public var isRunning: Bool

    public init(bundleID: String, label: String, isRunning: Bool) {
        self.bundleID = bundleID
        self.label = label
        self.isRunning = isRunning
    }

    public var kind: SessionKind { .app(bundleID: bundleID) }
    public var isActive: Bool { isRunning }
}
