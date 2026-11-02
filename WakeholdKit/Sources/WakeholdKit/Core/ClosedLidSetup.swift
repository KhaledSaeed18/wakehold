import Foundation

// One-time install and removal of the sudoers rule that ClosedLidHold runs through. The rule
// allows exactly two commands for one user, and visudo checks the file before it goes in place,
// since a broken file in sudoers.d breaks sudo for the whole machine.
public enum ClosedLidSetup {
    public enum SetupError: Error, Equatable {
        case invalidUserName
        case canceled
        case failed(String)
    }

    static let rulePath = "/etc/sudoers.d/wakehold"

    // Shows the system admin prompt; blocks until it is answered. Call it off the main actor.
    public static func install(user: String = NSUserName()) throws {
        try runAsAdmin(installScript(user: user))
    }

    // Turns sleep back on before removing the rule, so nothing is left set that can no longer be
    // cleared without a password.
    public static func remove() throws {
        try runAsAdmin("/usr/bin/pmset -a disablesleep 0; /bin/rm -f \(rulePath)")
    }

    static func rule(user: String) throws -> String {
        // The name is spliced into a root shell script and a sudoers line, so allow only the
        // characters macOS short names use.
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        guard !user.isEmpty, !user.hasPrefix("-"), user.unicodeScalars.allSatisfy(allowed.contains) else {
            throw SetupError.invalidUserName
        }
        let off = ClosedLidHold.pmsetArguments(false).joined(separator: " ")
        let on = ClosedLidHold.pmsetArguments(true).joined(separator: " ")
        return "\(user) ALL=(root) NOPASSWD: \(off), \(on)"
    }

    static func installScript(user: String) throws -> String {
        let lines = [
            "# Installed by Wakehold to turn system sleep off while a session holds with the lid closed.",
            try rule(user: user),
        ]
        return """
        set -e
        tmp=$(/usr/bin/mktemp)
        trap '/bin/rm -f "$tmp"' EXIT
        /usr/bin/printf '%s\\n' \(lines.map { "'\($0)'" }.joined(separator: " ")) > "$tmp"
        /usr/sbin/visudo -cf "$tmp"
        /usr/bin/install -m 0440 -o root -g wheel "$tmp" \(rulePath)
        """
    }

    static func appleScript(forShell script: String) -> String {
        let escaped = script
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "do shell script \"\(escaped)\" with administrator privileges"
    }

    // osascript in a child process, so the admin prompt never blocks the app's main thread.
    private static func runAsAdmin(_ script: String) throws {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript(forShell: script)]
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            throw SetupError.failed(String(describing: error))
        }
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        guard process.terminationStatus != 0 else { return }
        // -128 is AppleScript's "User canceled".
        throw output.contains("-128") ? SetupError.canceled : SetupError.failed(output)
    }
}
