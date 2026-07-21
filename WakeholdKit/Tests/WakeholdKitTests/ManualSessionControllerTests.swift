import Testing
import Foundation
@testable import WakeholdKit

@MainActor
struct ManualSessionControllerTests {
    @Test func startHoldsAwake() {
        let wake = WakeController()
        let manual = ManualSessionController(wake: wake)
        manual.start(label: "1 hour", seconds: 3600)
        #expect(wake.isAwake)
        #expect(wake.isHoldingAssertion)
        #expect(wake.sessions.count == 1)
    }

    @Test func stopReleases() {
        let wake = WakeController()
        let manual = ManualSessionController(wake: wake)
        manual.start(label: "1 hour", seconds: 3600)
        manual.stop()
        #expect(!wake.isAwake)
        #expect(wake.sessions.isEmpty)
    }

    @Test func startReplacesExistingSession() {
        let wake = WakeController()
        let manual = ManualSessionController(wake: wake)
        manual.start(label: "1 hour", seconds: 3600)
        manual.start(label: "2 hours", seconds: 7200)
        #expect(wake.sessions.count == 1)
        let remaining = wake.sessions.compactMap { $0 as? ManualSession }.first
        #expect(remaining?.label == "2 hours")
    }

    @Test func indefiniteHoldsAwake() {
        let wake = WakeController()
        let manual = ManualSessionController(wake: wake)
        manual.start(label: "Indefinite", seconds: nil)
        #expect(wake.isAwake)
        #expect(wake.isHoldingAssertion)
    }

    @Test func isRunningReflectsState() {
        let wake = WakeController()
        let manual = ManualSessionController(wake: wake)
        #expect(!manual.isRunning)
        manual.start(label: "1 hour", seconds: 3600)
        #expect(manual.isRunning)
        manual.stop()
        #expect(!manual.isRunning)
    }

    @Test func timedSessionExpiresAtTarget() async {
        let wake = WakeController()
        let manual = ManualSessionController(wake: wake)
        manual.start(ManualSession(label: "1 hour", until: Date(timeIntervalSinceNow: 0.3)))
        #expect(wake.isAwake)
        try? await Task.sleep(for: .seconds(0.8))
        #expect(!wake.isAwake)
        #expect(wake.sessions.isEmpty)
    }
}
