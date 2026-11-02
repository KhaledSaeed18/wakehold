import Foundation

// Keeps the Mac awake with the lid closed by turning system sleep off (`pmset -a disablesleep 1`)
// while Wakehold holds. Lid-close sleep ignores power assertions, and the only switch past it is
// this root-only setting, so it runs through the narrow sudoers rule ClosedLidSetup installs.
// Unlike an assertion, the setting outlives the process: the app clears it on quit, and on launch
// in case a crash left it set.
@MainActor
public final class ClosedLidHold: LidHolding {
    private var isApplied = false
    private let queue = DispatchQueue(label: "app.wakehold.closed-lid")

    public init() {}

    // Runs off the main actor; the serial queue keeps the order of on and off.
    public func setHeld(_ held: Bool) {
        isApplied = held
        queue.async { ClosedLidHold.applySleepDisabled(held) }
    }

    // Blocks until sleep is back on, so it lands before the process exits.
    public func releaseNow() {
        guard isApplied else { return }
        isApplied = false
        queue.sync { ClosedLidHold.applySleepDisabled(false) }
    }

    // A crash or SIGKILL skips releaseNow, leaving sleep off. Once the rule is installed Wakehold
    // owns the setting, so a set value with nothing held at launch is a leftover.
    public func clearStaleHold() {
        queue.async {
            guard ClosedLidHold.isAuthorized(), ClosedLidHold.isSleepDisabled() else { return }
            ClosedLidHold.applySleepDisabled(false)
        }
    }

    // Whether the sudoers rule lets this user run the setting without a password. Blocking; call it
    // off the main actor.
    public nonisolated static func isAuthorized() -> Bool {
        run("/usr/bin/sudo", ["-n", "-l"] + pmsetArguments(true)).status == 0
    }

    public nonisolated static func isSleepDisabled() -> Bool {
        parseSleepDisabled(run("/usr/bin/pmset", ["-g"]).output)
    }

    // pmset prints the SleepDisabled row only when it is set.
    nonisolated static func parseSleepDisabled(_ pmsetOutput: String) -> Bool {
        pmsetOutput.split(separator: "\n").contains { line in
            let fields = line.split(whereSeparator: \.isWhitespace)
            return fields.count >= 2 && fields[0] == "SleepDisabled" && fields[1] == "1"
        }
    }

    nonisolated static func pmsetArguments(_ disabled: Bool) -> [String] {
        ["/usr/bin/pmset", "-a", "disablesleep", disabled ? "1" : "0"]
    }

    private nonisolated static func applySleepDisabled(_ disabled: Bool) {
        let result = run("/usr/bin/sudo", ["-n"] + pmsetArguments(disabled))
        guard result.status != 0 else { return }
        Log.make("ClosedLidHold").error("pmset disablesleep failed: \(result.output, privacy: .public)")
    }

    private nonisolated static func run(_ path: String, _ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return (-1, String(describing: error))
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}
