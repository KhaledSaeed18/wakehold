import Testing
import Foundation
@testable import WakeholdKit

struct SystemAssertionsTests {
    // Mock in the exact shape IOPMCopyAssertionsByProcess returns: keyed by owner pid, each value a
    // list of that process's assertion dictionaries.
    private let raw: [AnyHashable: Any] = [
        8811: [
            ["AssertType": "PreventUserIdleDisplaySleep", "AssertPID": 8811, "Process Name": "caffeinate",
             "HumanReadableReason": "keeping awake", "Details": "on behalf of 8728"],
            ["AssertType": "PreventUserIdleSystemSleep", "AssertPID": 8811, "Process Name": "caffeinate"],
        ],
        419: [
            ["AssertType": "PreventUserIdleSystemSleep", "AssertPID": 419, "Process Name": "coreaudiod",
             "Details": "audio-out"],
        ],
        407: [
            ["AssertType": "UserIsActive", "AssertPID": 407, "Process Name": "WindowServer"],
        ],
        348: [
            ["AssertType": "PreventUserIdleSystemSleep", "AssertPID": 348, "Process Name": "powerd",
             "AssertName": "Powerd - Prevent sleep while display is on"],
        ],
    ]

    @Test func parseMapsHoldsAndDropsNonHolds() {
        let parsed = SystemAssertions.parse(raw)
        #expect(parsed.count == 3)                                   // UserIsActive dropped
        #expect(!parsed.contains { $0.processName == "WindowServer" })
        let display = parsed.first { $0.scope == .display }
        #expect(display?.processName == "caffeinate")
    }

    @Test func parsePrefersHumanReasonThenDetails() {
        let parsed = SystemAssertions.parse(raw)
        let caffeinateDisplay = parsed.first { $0.pid == 8811 && $0.scope == .display }
        #expect(caffeinateDisplay?.reason == "keeping awake")        // HumanReadableReason wins
        let audio = parsed.first { $0.pid == 419 }
        #expect(audio?.reason == "audio-out")                        // falls back to Details
    }

    @Test func parseDropsAmbientPowerd() {
        let parsed = SystemAssertions.parse(raw)
        #expect(!parsed.contains { $0.processName == "powerd" })
    }

    @Test func parseFallsBackToPidWhenNameMissing() {
        let parsed = SystemAssertions.parse([5: [["AssertType": "PreventUserIdleSystemSleep", "AssertPID": 5]]])
        #expect(parsed.first?.processName == "pid 5")
        #expect(parsed.first?.reason == nil)
    }

    @Test func holdsCollapsePerProcessAndKeepReason() {
        let holds = SystemAssertions.holds(from: SystemAssertions.parse(raw), excluding: -1)
        #expect(holds.count == 2)                                    // caffeinate's two assertions merge
        let caffeinate = holds.first { $0.processName == "caffeinate" }
        #expect(caffeinate?.keepsDisplayAwake == true)               // it has a display assertion
        #expect(caffeinate?.reason == "keeping awake")
        let audio = holds.first { $0.processName == "coreaudiod" }
        #expect(audio?.keepsDisplayAwake == false)
    }

    @Test func holdsExcludeTheGivenPid() {
        let holds = SystemAssertions.holds(from: SystemAssertions.parse(raw), excluding: 8811)
        #expect(holds.count == 1)
        #expect(holds.first?.processName == "coreaudiod")
    }

    @Test func holdsSortDisplayKeepersFirstThenByName() {
        let input = [
            SystemAssertion(pid: 1, processName: "zeta", scope: .display, reason: nil),
            SystemAssertion(pid: 2, processName: "alpha", scope: .system, reason: nil),
            SystemAssertion(pid: 3, processName: "mike", scope: .system, reason: nil),
        ]
        let holds = SystemAssertions.holds(from: input, excluding: -1)
        #expect(holds.map(\.processName) == ["zeta", "alpha", "mike"])   // display first, then A→Z
    }
}
