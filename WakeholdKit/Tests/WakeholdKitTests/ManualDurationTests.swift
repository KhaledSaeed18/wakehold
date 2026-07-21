import Testing
@testable import WakeholdKit

struct ManualDurationTests {
    @Test func intervals() {
        #expect(ManualDuration.oneHour.interval == 3600)
        #expect(ManualDuration.twoHours.interval == 7200)
        #expect(ManualDuration.threeHours.interval == 10800)
        #expect(ManualDuration.indefinite.interval == nil)
    }

    @Test func labels() {
        #expect(ManualDuration.oneHour.label == "1h")
        #expect(ManualDuration.twoHours.label == "2h")
        #expect(ManualDuration.threeHours.label == "3h")
        #expect(ManualDuration.indefinite.label == "∞")
    }

    @Test func allCasesCoverEveryChoice() {
        #expect(ManualDuration.allCases.count == 4)
    }
}
