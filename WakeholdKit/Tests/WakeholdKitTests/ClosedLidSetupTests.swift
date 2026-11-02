import Testing
import Foundation
@testable import WakeholdKit

struct ClosedLidSetupTests {
    @Test func parsesSleepDisabledRow() {
        #expect(ClosedLidHold.parseSleepDisabled(" sleep 1\n SleepDisabled\t\t1\n displaysleep 10\n"))
        #expect(!ClosedLidHold.parseSleepDisabled(" SleepDisabled\t\t0\n"))
        #expect(!ClosedLidHold.parseSleepDisabled(" sleep 1\n displaysleep 10\n"))
    }

    @Test func ruleAllowsOnlyTheTwoCommands() throws {
        let rule = try ClosedLidSetup.rule(user: "khaled.s")
        #expect(rule == "khaled.s ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1")
    }

    @Test(arguments: ["", "-r", "a b", "x;rm", "a'b", "a\"b", "root\nALL", "ü"])
    func rejectsUnsafeUserNames(_ name: String) {
        #expect(throws: ClosedLidSetup.SetupError.invalidUserName) { try ClosedLidSetup.rule(user: name) }
    }

    @Test func installScriptValidatesBeforeInstalling() throws {
        let script = try ClosedLidSetup.installScript(user: "khaled")
        let check = try #require(script.range(of: "visudo -cf"))
        let install = try #require(script.range(of: "/usr/bin/install -m 0440 -o root -g wheel"))
        #expect(check.lowerBound < install.lowerBound)
        #expect(script.hasPrefix("set -e\n"))
        #expect(script.contains("/etc/sudoers.d/wakehold"))
    }

    @Test func appleScriptEscapesQuotesAndBackslashes() {
        let source = ClosedLidSetup.appleScript(forShell: #"printf '%s\n' "x""#)
        #expect(source == #"do shell script "printf '%s\\n' \"x\"" with administrator privileges"#)
    }

    // Runs the install script's printf and visudo steps without root: the file it would install
    // must pass sudo's own syntax check.
    @Test func generatedRulePassesVisudo() throws {
        let script = try ClosedLidSetup.installScript(user: NSUserName())
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("wakehold").path
        let printf = try #require(script.split(separator: "\n").first { $0.hasPrefix("/usr/bin/printf") })
        let dryRun = printf.replacingOccurrences(of: "\"$tmp\"", with: "'\(file)'") + "\n/usr/sbin/visudo -cf '\(file)'"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", dryRun]
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        let contents = try String(contentsOfFile: file, encoding: .utf8)
        #expect(contents.hasSuffix("NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1\n"))
    }
}
