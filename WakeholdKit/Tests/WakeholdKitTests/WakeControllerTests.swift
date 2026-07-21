import Testing
import Foundation
@testable import WakeholdKit

// A controllable stand-in so the reconcile invariant can be driven without real processes or ports.
private struct MockSession: WakeSession {
    var id = UUID()
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

    @Test func suppressionReleasesThenResumes() {
        let controller = WakeController()
        controller.add(MockSession(isActive: true))
        #expect(controller.isHoldingAssertion)
        controller.setSuppressed(true)
        #expect(!controller.isAwake)
        #expect(!controller.isHoldingAssertion)
        controller.setSuppressed(false)
        #expect(controller.isAwake)
        #expect(controller.isHoldingAssertion)
    }

    @Test func onSessionsEmptiedFiresWhenLastSessionEnds() {
        let controller = WakeController()
        var fired = 0
        controller.onSessionsEmptied = { fired += 1 }
        let session = MockSession(isActive: true)
        controller.add(session)
        #expect(fired == 0)
        controller.remove(session.id)
        #expect(fired == 1)
    }

    @Test func onSessionsEmptiedIgnoresSuppression() {
        let controller = WakeController()
        var fired = 0
        controller.onSessionsEmptied = { fired += 1 }
        controller.add(MockSession(isActive: true))
        controller.setSuppressed(true)   // a guardrail pauses the hold, but the session is still active
        #expect(fired == 0)
    }

    @Test func defaultsToKeepingTheDisplayAwake() {
        let controller = WakeController()
        controller.add(MockSession(isActive: true))
        #expect(controller.keepDisplayAwake)
        #expect(controller.heldScope == .display)
    }

    @Test func lettingTheDisplaySleepReScopesTheLiveAssertion() {
        let controller = WakeController()
        controller.add(MockSession(isActive: true))
        #expect(controller.heldScope == .display)
        controller.setKeepDisplayAwake(false)
        #expect(controller.isHoldingAssertion)   // still awake, just no longer holding the screen
        #expect(controller.heldScope == .system)
        controller.setKeepDisplayAwake(true)
        #expect(controller.heldScope == .display)
    }

    @Test func displayPreferenceAppliesToTheNextAcquire() {
        let controller = WakeController()
        controller.setKeepDisplayAwake(false)    // set before any session exists
        #expect(controller.heldScope == nil)     // nothing held yet, so nothing to re-scope
        controller.add(MockSession(isActive: true))
        #expect(controller.heldScope == .system)
    }

    @Test func presentSessionGoingInactiveDoesNotFireEmptied() {
        let controller = WakeController()
        var emptied = 0
        controller.onSessionsEmptied = { emptied += 1 }
        let session = MockSession(isActive: true)
        controller.add(session)
        controller.update(MockSession(id: session.id, isActive: false))
        #expect(emptied == 0)
        #expect(!controller.isHoldingAssertion)
    }

    @Test func presentSessionGoingActiveAgainReacquiresAndFiresResumed() {
        let controller = WakeController()
        let session = MockSession(isActive: true)
        controller.add(session)
        controller.update(MockSession(id: session.id, isActive: false))
        var resumed = 0
        controller.onSessionsResumed = { resumed += 1 }
        #expect(resumed == 0)
        controller.update(MockSession(id: session.id, isActive: true))
        #expect(controller.isHoldingAssertion)
        #expect(resumed == 1)
    }

    @Test func removingLastSessionWhileActiveFiresEmptied() {
        let controller = WakeController()
        var emptied = 0
        controller.onSessionsEmptied = { emptied += 1 }
        let session = MockSession(isActive: true)
        controller.add(session)
        controller.remove(session.id)
        #expect(emptied == 1)
    }

    @Test func suppressionToggleFiresNeitherHook() {
        let controller = WakeController()
        controller.add(MockSession(isActive: true))
        var emptied = 0
        var resumed = 0
        controller.onSessionsEmptied = { emptied += 1 }
        controller.onSessionsResumed = { resumed += 1 }
        controller.setSuppressed(true)
        controller.setSuppressed(false)
        #expect(emptied == 0)
        #expect(resumed == 0)
    }
}
