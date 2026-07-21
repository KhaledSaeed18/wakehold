import Testing
import Foundation
@testable import WakeholdKit

@MainActor
struct ProcessSessionTests {
    @Test func holdsWhileProcessLivesThenReleasesOnExit() async throws {
        let wake = WakeController()
        let registry = SessionRegistry(wake: wake)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sleep")
        proc.arguments = ["30"]
        try proc.run()
        defer { if proc.isRunning { proc.terminate() } }

        let id = registry.startProcess(pid: proc.processIdentifier, label: "sleep")
        #expect(id != nil)
        #expect(wake.isAwake)
        #expect(wake.isHoldingAssertion)

        // Killing it should fire the dispatch source and remove the session.
        proc.terminate()
        try await pollUntil(timeout: 5) { wake.sessions.isEmpty }
        #expect(!wake.isAwake)
        #expect(!wake.isHoldingAssertion)
        #expect(wake.sessions.isEmpty)
    }

    @Test func startingDeadProcessReturnsNil() {
        let wake = WakeController()
        let registry = SessionRegistry(wake: wake)
        let id = registry.startProcess(pid: 999_999, label: "ghost")
        #expect(id == nil)
        #expect(!wake.isAwake)
        #expect(wake.sessions.isEmpty)
    }

    @Test func endRemovesSession() throws {
        let wake = WakeController()
        let registry = SessionRegistry(wake: wake)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sleep")
        proc.arguments = ["30"]
        try proc.run()
        defer { if proc.isRunning { proc.terminate() } }

        let id = registry.startProcess(pid: proc.processIdentifier, label: "sleep")
        #expect(wake.isAwake)
        if let id { registry.end(id) }
        #expect(!wake.isAwake)
        #expect(wake.sessions.isEmpty)
    }
}
