import Testing
import Foundation
@testable import WakeholdKit

private let cliBinaryPath = ".build/debug/wakehold"

// Drives the actual built wakehold binary against an in-process endpoint. Skipped unless the
// binary has been built (swift build), so `swift test` alone still passes.
@MainActor
@Suite(.enabled(if: FileManager.default.fileExists(atPath: cliBinaryPath)))
struct CLIEndToEndTests {
    @Test func statusReportsSessionsFromTheEndpoint() async throws {
        let wake = WakeController()
        let registry = SessionRegistry(wake: wake)
        let path = "/tmp/wh-\(UUID().uuidString.prefix(8)).sock"
        let server = ControlServer(path: path, wake: wake, registry: registry)
        try server.start()
        defer { server.stop() }
        _ = registry.startAgent(label: "claude-code", ttl: 600)

        let output = try await Task.detached { try runCLI(["status"], socket: path) }.value
        #expect(output.contains("Awake"))
        #expect(output.contains("claude-code"))
    }

    @Test func commandWrapperHoldsThenReleases() async throws {
        let wake = WakeController()
        let registry = SessionRegistry(wake: wake)
        let path = "/tmp/wh-\(UUID().uuidString.prefix(8)).sock"
        let server = ControlServer(path: path, wake: wake, registry: registry)
        try server.start()
        defer { server.stop() }

        // `wakehold -- sleep 1` holds while it runs, then releases on exit.
        let task = Task.detached { try runCLI(["--", "sleep", "1"], socket: path) }
        try await pollUntil(timeout: 3) { wake.isAwake }
        #expect(wake.isAwake)
        _ = try await task.value
        try await pollUntil(timeout: 3) { !wake.isAwake }
        #expect(!wake.isAwake)
    }

    @Test func hookStartAndEndKeyedBySessionId() async throws {
        let wake = WakeController()
        let registry = SessionRegistry(wake: wake)
        let path = "/tmp/wh-\(UUID().uuidString.prefix(8)).sock"
        let server = ControlServer(path: path, wake: wake, registry: registry)
        try server.start()
        defer { server.stop() }

        let event = #"{"session_id":"abc123","cwd":"/Users/me/project","hook_event_name":"SessionStart"}"#
        _ = try await Task.detached { try runCLI(["hook", "start"], socket: path, stdin: event) }.value
        #expect(wake.isAwake)
        #expect(wake.sessions.contains { $0.label == "project" })   // cwd basename becomes the label

        _ = try await Task.detached { try runCLI(["hook", "end"], socket: path, stdin: event) }.value
        #expect(!wake.isAwake)
    }
}

private func runCLI(_ args: [String], socket: String, stdin: String? = nil) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: cliBinaryPath)
    process.arguments = args
    var environment = ProcessInfo.processInfo.environment
    environment["WAKEHOLD_SOCKET"] = socket
    process.environment = environment
    let output = Pipe()
    process.standardOutput = output
    process.standardError = Pipe()
    if let stdin {
        let input = Pipe()
        process.standardInput = input
        try process.run()
        input.fileHandleForWriting.write(Data(stdin.utf8))
        try? input.fileHandleForWriting.close()
    } else {
        try process.run()
    }
    process.waitUntilExit()
    return String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
}
