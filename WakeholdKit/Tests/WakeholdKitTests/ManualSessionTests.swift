import Testing
import Foundation
@testable import WakeholdKit

struct ManualSessionTests {
    @Test func timedSessionActiveBeforeTarget() {
        let session = ManualSession(label: "1 hour", seconds: 3600)
        #expect(session.isActive)
        #expect(session.until != nil)
    }

    @Test func timedSessionInactiveAfterTarget() {
        // Started two hours ago with a one-hour duration: the target is an hour in the past.
        let session = ManualSession(label: "1 hour", seconds: 3600, now: Date(timeIntervalSinceNow: -7200))
        #expect(!session.isActive)
    }

    @Test func indefiniteSessionAlwaysActive() {
        let session = ManualSession(label: "Indefinite", seconds: nil)
        #expect(session.until == nil)
        #expect(session.isActive)
    }

    @Test func untilComputedFromSeconds() {
        let now = Date()
        let session = ManualSession(label: "2 hours", seconds: 7200, now: now)
        #expect(session.until == now.addingTimeInterval(7200))
    }
}
