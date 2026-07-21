import Testing
import Foundation
@testable import WakeholdKit

@MainActor
struct ManualSessionControllerTests {
    @Test func startHoldsAwake() {
        let wake = WakeController()
        let manual = ManualSessionController(wake: wake)
        manual.start(.oneHour)
        #expect(wake.isAwake)
        #expect(wake.isHoldingAssertion)
        #expect(wake.sessions.count == 1)
    }

    @Test func stopReleases() {
        let wake = WakeController()
        let manual = ManualSessionController(wake: wake)
        manual.start(.oneHour)
        manual.stop()
        #expect(!wake.isAwake)
        #expect(!wake.isHoldingAssertion)
        #expect(wake.sessions.isEmpty)
    }

    @Test func startReplacesExistingSession() {
        let wake = WakeController()
        let manual = ManualSessionController(wake: wake)
        manual.start(.oneHour)
        manual.start(.twoHours)
        #expect(wake.sessions.count == 1)
        let remaining = wake.sessions.compactMap { $0 as? ManualSession }.first
        #expect(remaining?.duration == .twoHours)
    }

    @Test func indefiniteHoldsAwake() {
        let wake = WakeController()
        let manual = ManualSessionController(wake: wake)
        manual.start(.indefinite)
        #expect(wake.isAwake)
        #expect(wake.isHoldingAssertion)
    }

    @Test func timedSessionExpiresAtTarget() async {
        let wake = WakeController()
        let manual = ManualSessionController(wake: wake)
        manual.start(ManualSession(duration: .oneHour, until: Date(timeIntervalSinceNow: 0.3)))
        #expect(wake.isAwake)
        try? await Task.sleep(for: .seconds(0.8))
        #expect(!wake.isAwake)
        #expect(wake.sessions.isEmpty)
    }
}
