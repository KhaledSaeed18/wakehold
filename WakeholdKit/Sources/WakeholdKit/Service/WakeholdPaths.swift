import Foundation

// The one place that knows where the control socket lives, so the app and the CLI agree.
public enum WakeholdPaths {
    public static func socket() -> String {
        let dir = supportDirectory()
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir + "/wakehold.sock"
    }

    private static func supportDirectory() -> String {
        if let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return base.appendingPathComponent("Wakehold", isDirectory: true).path
        }
        return NSHomeDirectory() + "/Library/Application Support/Wakehold"
    }
}
