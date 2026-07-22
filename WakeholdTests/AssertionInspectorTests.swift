import Testing
import Foundation
import WakeholdKit
@testable import Wakehold

@MainActor
struct AssertionInspectorTests {
    @Test func startPublishesHoldsFromTheReader() {
        let holds = [
            ProcessHold(pid: 1, processName: "zoom.us", keepsDisplayAwake: true, reason: "call"),
            ProcessHold(pid: 2, processName: "Music", keepsDisplayAwake: false, reason: nil),
        ]
        let inspector = AssertionInspector(interval: 3600, reader: { holds })
        #expect(inspector.holds.isEmpty)          // nothing before start
        inspector.start()
        #expect(inspector.holds == holds)         // start reads once and publishes
    }

    @Test func startIsIdempotent() {
        let inspector = AssertionInspector(interval: 3600, reader: { [] })
        inspector.start()
        inspector.start()                          // a second start must not re-arm or crash
        #expect(inspector.holds.isEmpty)
    }
}
