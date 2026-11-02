import AppKit
import Observation
import WakeholdKit

// What Settings shows about the clients of the control endpoint: whether the wakehold CLI is
// installed, and whether Claude Code's hooks point at it. File checks run off the main actor.
@MainActor
@Observable
final class IntegrationStatus {
    private(set) var cliPath: String?
    private(set) var isClaudeCodeConnected = false
    let socketPath = WakeholdPaths.socket()

    // A login item starts with launchd's minimal PATH, not the user's shell PATH, so look in the
    // places the README and package managers link the CLI.
    nonisolated static let cliCandidates = [
        "/usr/local/bin/wakehold",
        "/opt/homebrew/bin/wakehold",
        "~/.local/bin/wakehold",
        "~/bin/wakehold",
    ]

    nonisolated static let claudeSettingsPath = "~/.claude/settings.json"

    nonisolated static let claudeHooksConfig = """
    {
      "hooks": {
        "SessionStart": [{ "hooks": [{ "type": "command", "command": "wakehold hook start" }] }],
        "PostToolUse":  [{ "hooks": [{ "type": "command", "command": "wakehold hook renew" }] }],
        "Stop":         [{ "hooks": [{ "type": "command", "command": "wakehold hook renew" }] }],
        "SessionEnd":   [{ "hooks": [{ "type": "command", "command": "wakehold hook end" }] }]
      }
    }
    """

    func refresh() {
        DispatchQueue.global(qos: .utility).async {
            let cli = Self.findCLI()
            let connected = Self.hasClaudeHooks()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.cliPath = cli
                    self.isClaudeCodeConnected = connected
                }
            }
        }
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    nonisolated static func findCLI(candidates: [String] = cliCandidates) -> String? {
        candidates
            .map { NSString(string: $0).expandingTildeInPath }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    // A text match rather than a JSON walk: the hook command is the contract, and settings files
    // carry comments and shapes that a strict decode would reject.
    nonisolated static func hasClaudeHooks(at path: String = claudeSettingsPath) -> Bool {
        let url = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return false }
        return text.contains("wakehold hook start")
    }
}
