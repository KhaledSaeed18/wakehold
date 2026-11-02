import Testing
import Foundation
@testable import Wakehold

struct IntegrationStatusTests {
    private func tempFile(_ contents: String) throws -> String {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        try contents.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    @Test func detectsClaudeHooksByTheHookCommand() throws {
        let connected = try tempFile(IntegrationStatus.claudeHooksConfig)
        let other = try tempFile(#"{ "hooks": { "Stop": [] } }"#)
        #expect(IntegrationStatus.hasClaudeHooks(at: connected))
        #expect(!IntegrationStatus.hasClaudeHooks(at: other))
        #expect(!IntegrationStatus.hasClaudeHooks(at: "/nonexistent/settings.json"))
    }

    @Test func findsTheFirstExecutableCandidate() throws {
        let plain = try tempFile("not executable")
        let executable = try tempFile("#!/bin/sh\n")
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable)
        #expect(IntegrationStatus.findCLI(candidates: ["/nonexistent/wakehold", plain, executable]) == executable)
        #expect(IntegrationStatus.findCLI(candidates: ["/nonexistent/wakehold", plain]) == nil)
    }
}
