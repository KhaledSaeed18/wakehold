import Foundation
import IOKit.pwr_mgt
import UserNotifications

// The real end-action mechanisms. All user-space or one-time TCC (ADR-014): no root helper. This
// is the only place that sleeps the machine or scripts System Events.
public struct SystemActions: SystemActing {
    private let log = Log.make("SystemActions")

    public init() {}

    public func run(_ action: PostSessionAction) {
        switch action {
        case .none: break
        case .notify: warn("The last session ended.")
        case .displaySleep: shell("/usr/bin/pmset", ["displaysleepnow"])
        case .systemSleep: sleepSystem()
        case .shutDown: appleScript("tell application \"System Events\" to shut down")
        case .restart: appleScript("tell application \"System Events\" to restart")
        }
    }

    public func warn(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Wakehold"
        content.body = message
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    private func sleepSystem() {
        let connection = IOPMFindPowerManagement(kIOMainPortDefault)
        guard connection != 0 else { return }
        IOPMSleepSystem(connection)
        IOServiceClose(connection)
    }

    private func shell(_ path: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        try? process.run()
    }

    private func appleScript(_ source: String) {
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            log.error("apple script failed: \(String(describing: error), privacy: .public)")
        }
    }
}
