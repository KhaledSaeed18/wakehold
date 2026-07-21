import Testing
import Foundation
@testable import WakeholdKit

@MainActor
struct AgentLeaseTests {
    @Test func leaseHoldsThenExpiresAfterTTL() async {
        let wake = WakeController()
        let registry = SessionRegistry(wake: wake)
        _ = registry.startAgent(label: "claude-code", ttl: 0.3)
        #expect(wake.isAwake)
        #expect(wake.isHoldingAssertion)
        try? await Task.sleep(for: .seconds(0.6))
        #expect(!wake.isAwake)
        #expect(wake.sessions.isEmpty)
    }

    @Test func renewExtendsTheLease() async {
        let wake = WakeController()
        let registry = SessionRegistry(wake: wake)
        let id = registry.startAgent(label: "agent", ttl: 0.5)
        try? await Task.sleep(for: .seconds(0.2))
        #expect(registry.renew(id))            // resets the clock at t=0.2, so it now expires ~t=0.7
        try? await Task.sleep(for: .seconds(0.3))   // t=0.5, still before 0.7
        #expect(wake.isAwake)
        try? await Task.sleep(for: .seconds(0.5))   // t=1.0, past 0.7
        #expect(!wake.isAwake)
    }

    @Test func renewUnknownLeaseReturnsFalse() {
        let wake = WakeController()
        let registry = SessionRegistry(wake: wake)
        #expect(!registry.renew(UUID()))
    }

    @Test func endStopsLeaseBeforeExpiry() {
        let wake = WakeController()
        let registry = SessionRegistry(wake: wake)
        let id = registry.startAgent(label: "agent", ttl: 60)
        #expect(wake.isAwake)
        registry.end(id)
        #expect(!wake.isAwake)
        #expect(wake.sessions.isEmpty)
    }

    @Test func keyedStartIsIdempotentAndRenewable() {
        let wake = WakeController()
        let registry = SessionRegistry(wake: wake)
        let first = registry.startAgent(key: "sess-1", label: "claude", ttl: 60)
        let second = registry.startAgent(key: "sess-1", label: "claude", ttl: 60)
        #expect(first == second)                 // same key reuses the one lease
        #expect(wake.sessions.count == 1)
        #expect(registry.renew(key: "sess-1"))
        #expect(!registry.renew(key: "missing"))
    }

    @Test func endKeyStopsTheKeyedLease() {
        let wake = WakeController()
        let registry = SessionRegistry(wake: wake)
        _ = registry.startAgent(key: "sess-2", label: "claude", ttl: 60)
        #expect(wake.isAwake)
        registry.endKey("sess-2")
        #expect(!wake.isAwake)
        #expect(wake.sessions.isEmpty)
        #expect(!registry.renew(key: "sess-2"))   // the key is gone
    }
}
