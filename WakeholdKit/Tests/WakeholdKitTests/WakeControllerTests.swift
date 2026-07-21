import Testing
import Foundation
@testable import WakeholdKit

// A controllable stand-in so the reconcile invariant can be driven without real processes or ports.
private struct MockSession: WakeSession {
    let id = UUID()
    var label = "mock"
    var kind: SessionKind = .agent(label: "mock")
    var isActive: Bool
}

@MainActor
struct WakeControllerTests {
    @Test func addingActiveSessionAcquiresAssertion() {
        let controller = WakeController()
        controller.add(MockSession(isActive: true))
        #expect(controller.isAwake)
        #expect(controller.isHoldingAssertion)
    }

    @Test func addingInactiveSessionDoesNotAcquire() {
        let controller = WakeController()
        controller.add(MockSession(isActive: false))
        #expect(!controller.isAwake)
        #expect(!controller.isHoldingAssertion)
    }

    @Test func removingLastActiveSessionReleases() {
        let controller = WakeController()
        let session = MockSession(isActive: true)
        controller.add(session)
        #expect(controller.isHoldingAssertion)
        controller.remove(session.id)
        #expect(!controller.isAwake)
        #expect(!controller.isHoldingAssertion)
    }

    @Test func assertionHeldWhileAnyActiveRemains() {
        let controller = WakeController()
        let first = MockSession(isActive: true)
        let second = MockSession(isActive: true)
        controller.add(first)
        controller.add(second)
        controller.remove(first.id)
        #expect(controller.isHoldingAssertion)
        controller.remove(second.id)
        #expect(!controller.isHoldingAssertion)
    }

    @Test func inactiveSessionAloneDoesNotHold() {
        let controller = WakeController()
        let active = MockSession(isActive: true)
        let idle = MockSession(isActive: false)
        controller.add(active)
        controller.add(idle)
        #expect(controller.isHoldingAssertion)
        controller.remove(active.id)
        #expect(!controller.isAwake)
        #expect(!controller.isHoldingAssertion)
    }
}
