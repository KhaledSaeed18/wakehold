import Testing
import Foundation
@testable import WakeholdKit

@MainActor
struct ControlClientTests {
    private func makeServer() throws -> (WakeController, ControlServer, ControlClient) {
        let wake = WakeController()
        let registry = SessionRegistry(wake: wake)
        let path = "/tmp/wh-\(UUID().uuidString.prefix(8)).sock"
        let server = ControlServer(path: path, wake: wake, registry: registry)
        try server.start()
        return (wake, server, ControlClient(path: path))
    }

    @Test func startsStatusesAndEndsOverSocket() async throws {
        let (wake, server, client) = try makeServer()
        defer { server.stop() }

        let id = try await Task.detached { try client.startAgent(label: "claude-code", ttl: 600) }.value
        #expect(wake.isAwake)
        #expect(wake.isHoldingAssertion)

        let status = try await Task.detached { try client.status() }.value
        #expect(status.awake)
        #expect(status.sessions.contains { $0.label == "claude-code" && $0.kind == "agent" })

        try await Task.detached { try client.end(id) }.value
        #expect(!wake.isAwake)
    }

    @Test func offEndsEveryEndpointSession() async throws {
        let (wake, server, client) = try makeServer()
        defer { server.stop() }

        _ = try await Task.detached { try client.startAgent(label: "a", ttl: 600) }.value
        _ = try await Task.detached { try client.startAgent(label: "b", ttl: 600) }.value
        #expect(wake.sessions.count == 2)

        try await Task.detached { try client.off() }.value
        #expect(!wake.isAwake)
        #expect(wake.sessions.isEmpty)
    }

    @Test func unreachableEndpointThrows() async {
        let client = ControlClient(path: "/tmp/wh-missing-\(UUID().uuidString.prefix(8)).sock")
        await #expect(throws: WakeholdError.self) {
            try await Task.detached { try client.status() }.value
        }
    }
}
