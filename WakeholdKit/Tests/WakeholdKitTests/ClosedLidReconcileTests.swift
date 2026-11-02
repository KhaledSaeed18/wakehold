import Testing
import Foundation
@testable import WakeholdKit

private struct MockSession: WakeSession {
    var id = UUID()
    var label = "mock"
    var kind: SessionKind = .agent(label: "mock")
    var isActive: Bool
}

@MainActor
private final class SpyLid: LidHolding {
    private(set) var calls: [Bool] = []
    func setHeld(_ held: Bool) { calls.append(held) }
}

@MainActor
struct ClosedLidReconcileTests {
    @Test func offByDefaultNeverTouchesTheSetting() {
        let spy = SpyLid()
        let controller = WakeController(lid: spy)
        let session = MockSession(isActive: true)
        controller.add(session)
        controller.remove(session.id)
        #expect(spy.calls.isEmpty)
        #expect(!controller.isHoldingWithLidClosed)
    }

    @Test func heldOnlyWhileASessionIsActive() {
        let spy = SpyLid()
        let controller = WakeController(lid: spy)
        controller.setHoldsWithLidClosed(true)
        #expect(spy.calls.isEmpty)
        let session = MockSession(isActive: true)
        controller.add(session)
        #expect(controller.isHoldingWithLidClosed)
        controller.remove(session.id)
        #expect(!controller.isHoldingWithLidClosed)
        #expect(spy.calls == [true, false])
    }

    @Test func enablingWhileAwakeHoldsAndDisablingReleases() {
        let spy = SpyLid()
        let controller = WakeController(lid: spy)
        controller.add(MockSession(isActive: true))
        controller.setHoldsWithLidClosed(true)
        controller.setHoldsWithLidClosed(false)
        #expect(spy.calls == [true, false])
        #expect(controller.isHoldingAssertion)
    }

    @Test func guardrailSuppressionReleasesAndResumes() {
        let spy = SpyLid()
        let controller = WakeController(lid: spy)
        controller.setHoldsWithLidClosed(true)
        controller.add(MockSession(isActive: true))
        controller.setSuppressed(true)
        #expect(!controller.isHoldingWithLidClosed)
        controller.setSuppressed(false)
        #expect(spy.calls == [true, false, true])
    }

    @Test func inactiveSessionDoesNotHold() {
        let spy = SpyLid()
        let controller = WakeController(lid: spy)
        controller.setHoldsWithLidClosed(true)
        controller.add(MockSession(isActive: false))
        #expect(spy.calls.isEmpty)
    }

    @Test func extraSessionsDoNotRepeatTheCall() {
        let spy = SpyLid()
        let controller = WakeController(lid: spy)
        controller.setHoldsWithLidClosed(true)
        let first = MockSession(isActive: true)
        let second = MockSession(isActive: true)
        controller.add(first)
        controller.add(second)
        controller.remove(first.id)
        #expect(spy.calls == [true])
        controller.remove(second.id)
        #expect(spy.calls == [true, false])
    }
}
