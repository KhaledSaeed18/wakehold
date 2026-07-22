import Foundation
import IOKit.pwr_mgt

// Read-only inspection of every sleep-preventing power assertion on the system, not just Wakehold's.
// This is the observe-everything counterpart to PowerAssertion, which owns Wakehold's single hold.
// It never acquires or releases anything. The IOKit call is cheap (the same query pmset and Activity
// Monitor run); there is no push notification for it (the power-management Darwin keys do not post),
// so callers poll.

// A single sleep-preventing assertion held by some process, as read from IOKit.
public struct SystemAssertion: Sendable, Equatable {
    public enum Scope: Sendable, Equatable {
        case display   // keeps the screen lit (PreventUserIdleDisplaySleep)
        case system    // keeps the system awake, display may sleep
    }
    public let pid: pid_t
    public let processName: String
    public let scope: Scope
    public let reason: String?

    public init(pid: pid_t, processName: String, scope: Scope, reason: String?) {
        self.pid = pid
        self.processName = processName
        self.scope = scope
        self.reason = reason
    }
}

// One process's hold, collapsed across the several assertions it may own, for display.
public struct ProcessHold: Sendable, Equatable, Identifiable {
    public let pid: pid_t
    public let processName: String
    public let keepsDisplayAwake: Bool   // any of its assertions blocks display sleep
    public let reason: String?
    public var id: pid_t { pid }

    public init(pid: pid_t, processName: String, keepsDisplayAwake: Bool, reason: String?) {
        self.pid = pid
        self.processName = processName
        self.keepsDisplayAwake = keepsDisplayAwake
        self.reason = reason
    }
}

public enum SystemAssertions {
    // Every sleep-preventing assertion currently held on the system.
    public static func current() -> [SystemAssertion] {
        var out: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&out) == kIOReturnSuccess,
              let byProcess = out?.takeRetainedValue() as? [AnyHashable: Any] else {
            return []
        }
        return parse(byProcess)
    }

    // Other processes' holds, collapsed per process and with our own pid dropped, ready for the menu.
    public static func currentHolds(excluding excluded: pid_t) -> [ProcessHold] {
        holds(from: current(), excluding: excluded)
    }

    // Pure mapping from the IOPMCopyAssertionsByProcess shape to the model, so it is unit-tested
    // without IOKit. Keyed by owner pid; each value is that process's array of assertion dictionaries.
    static func parse(_ byProcess: [AnyHashable: Any]) -> [SystemAssertion] {
        var result: [SystemAssertion] = []
        for value in byProcess.values {
            guard let assertions = value as? [[String: Any]] else { continue }
            for assertion in assertions {
                guard let type = assertion["AssertType"] as? String, let scope = scope(for: type) else {
                    continue
                }
                let pid = (assertion["AssertPID"] as? Int).map(pid_t.init) ?? -1
                let name = (assertion["Process Name"] as? String) ?? "pid \(pid)"
                guard !ignoredProcesses.contains(name) else { continue }
                let reason = (assertion["HumanReadableReason"] as? String) ?? (assertion["Details"] as? String)
                result.append(SystemAssertion(pid: pid, processName: name, scope: scope, reason: reason))
            }
        }
        return result
    }

    // Collapse per-assertion rows into one hold per process, drop the excluded pid (ours), and sort
    // display-keepers first then by name, so the most intrusive holds lead.
    static func holds(from assertions: [SystemAssertion], excluding excluded: pid_t) -> [ProcessHold] {
        var byPid: [pid_t: ProcessHold] = [:]
        for assertion in assertions where assertion.pid != excluded {
            let existing = byPid[assertion.pid]
            byPid[assertion.pid] = ProcessHold(
                pid: assertion.pid,
                processName: existing?.processName ?? assertion.processName,
                keepsDisplayAwake: (existing?.keepsDisplayAwake ?? false) || assertion.scope == .display,
                reason: existing?.reason ?? assertion.reason)
        }
        return byPid.values.sorted {
            $0.keepsDisplayAwake != $1.keepsDisplayAwake
                ? $0.keepsDisplayAwake
                : $0.processName.localizedCaseInsensitiveCompare($1.processName) == .orderedAscending
        }
    }

    // powerd holds an ambient "prevent sleep while the display is on" assertion whenever the screen
    // is lit. It is a consequence of the display being on, not a reason a user is looking for, so it
    // is noise in a "why won't my Mac sleep" list and is dropped.
    private static let ignoredProcesses: Set<String> = ["powerd"]

    // Only the assertion types that actually hold the Mac awake. UserIsActive, NetworkClientActive,
    // BackgroundTask and the like churn constantly and are not user-meaningful holds, so drop them.
    private static func scope(for type: String) -> SystemAssertion.Scope? {
        switch type {
        case "PreventUserIdleDisplaySleep": .display
        case "PreventUserIdleSystemSleep", "PreventSystemSleep", "NoIdleSleepAssertion": .system
        default: nil
        }
    }
}
