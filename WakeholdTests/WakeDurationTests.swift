import Testing
import Foundation
@testable import Wakehold

// Labels resolve through the String Catalog, so these also confirm the English plural forms
// (singular "1 minute", not "1 minutes"). They assume the development locale is English.
@MainActor
struct WakeDurationTests {
    @Test func oneMinuteIsSingular() {
        #expect(WakeDuration(seconds: 60).label == "1 minute")
    }

    @Test func manyMinutesArePlural() {
        #expect(WakeDuration(seconds: 300).label == "5 minutes")
    }

    @Test func oneHourIsSingular() {
        #expect(WakeDuration(seconds: 3600).label == "1 hour")
    }

    @Test func manyHoursArePlural() {
        #expect(WakeDuration(seconds: 7200).label == "2 hours")
    }

    @Test func mixedHoursAndMinutesAreCompact() {
        #expect(WakeDuration(seconds: 9000).label == "2h 30m")   // 2h 30m
    }

    @Test func nilSecondsIsIndefinite() {
        #expect(WakeDuration(seconds: nil).label == "Indefinite")
    }

    @Test func builtInsAreTheExpectedSet() {
        #expect(WakeDuration.builtIns.map(\.seconds) == [3600, 7200, 10800, nil])
    }

    @Test func idsAreStableAcrossValueCopies() {
        let duration = WakeDuration(seconds: 3600)
        #expect(duration == duration)
        #expect(WakeDuration(seconds: 3600) != duration)   // fresh id each construction
    }
}
