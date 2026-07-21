import Testing
import Foundation
@testable import WakeholdKit

struct ManualSessionTests {
    @Test func timedSessionActiveBeforeTarget() {
        let session = ManualSession(duration: .oneHour)
        #expect(session.isActive)
        #expect(session.until != nil)
    }

    @Test func timedSessionInactiveAfterTarget() {
        // Started two hours ago with a one-hour duration: the target is an hour in the past.
        let session = ManualSession(duration: .oneHour, now: Date(timeIntervalSinceNow: -7200))
        #expect(!session.isActive)
    }

    @Test func indefiniteSessionAlwaysActive() {
        let session = ManualSession(duration: .indefinite)
        #expect(session.until == nil)
        #expect(session.isActive)
    }

    @Test func untilComputedFromInterval() {
        let now = Date()
        let session = ManualSession(duration: .twoHours, now: now)
        #expect(session.until == now.addingTimeInterval(7200))
    }

    @Test func labelMatchesDuration() {
        #expect(ManualSession(duration: .threeHours).label == "3h")
    }
}
