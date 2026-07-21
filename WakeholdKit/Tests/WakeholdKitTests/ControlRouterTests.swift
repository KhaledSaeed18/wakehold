import Testing
import Foundation
@testable import WakeholdKit

@MainActor
struct ControlRouterTests {
    private func makeRouter() -> (WakeController, ControlRouter) {
        let wake = WakeController()
        let registry = SessionRegistry(wake: wake)
        return (wake, ControlRouter(wake: wake, registry: registry))
    }

    @Test func startAgentReturnsIdAndHolds() throws {
        let (wake, router) = makeRouter()
        let body = #"{"kind":"agent","label":"claude-code","ttl":600}"#.data(using: .utf8)!
        let response = router.handle(Request(method: "POST", path: "/session/start", body: body))
        #expect(response.status == 200)
        let decoded = try JSONDecoder().decode(IDResponse.self, from: response.body)
        #expect(UUID(uuidString: decoded.id) != nil)
        #expect(wake.isAwake)
    }

    @Test func startProcessForDeadPidIs400() {
        let (_, router) = makeRouter()
        let body = #"{"kind":"process","pid":999999}"#.data(using: .utf8)!
        let response = router.handle(Request(method: "POST", path: "/session/start", body: body))
        #expect(response.status == 400)
    }

    @Test func endRemovesSession() throws {
        let (wake, router) = makeRouter()
        let start = router.handle(Request(method: "POST", path: "/session/start",
                                          body: #"{"kind":"agent","ttl":600}"#.data(using: .utf8)!))
        let id = try JSONDecoder().decode(IDResponse.self, from: start.body).id
        let response = router.handle(Request(method: "POST", path: "/session/end",
                                             body: "{\"id\":\"\(id)\"}".data(using: .utf8)!))
        #expect(response.status == 200)
        #expect(!wake.isAwake)
    }

    @Test func renewUnknownSessionIs404() {
        let (_, router) = makeRouter()
        let body = "{\"id\":\"\(UUID().uuidString)\"}".data(using: .utf8)!
        let response = router.handle(Request(method: "POST", path: "/session/renew", body: body))
        #expect(response.status == 404)
    }

    @Test func statusReportsSessions() throws {
        let (_, router) = makeRouter()
        _ = router.handle(Request(method: "POST", path: "/session/start",
                                  body: #"{"kind":"agent","label":"claude-code","ttl":600}"#.data(using: .utf8)!))
        let response = router.handle(Request(method: "GET", path: "/status", body: Data()))
        #expect(response.status == 200)
        let status = try JSONDecoder().decode(StatusResponse.self, from: response.body)
        #expect(status.awake)
        #expect(status.sessions.count == 1)
        #expect(status.sessions.first?.kind == "agent")
        #expect(status.sessions.first?.label == "claude-code")
    }

    @Test func unknownPathIs404() {
        let (_, router) = makeRouter()
        let response = router.handle(Request(method: "GET", path: "/nope", body: Data()))
        #expect(response.status == 404)
    }
}
