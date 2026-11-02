import Testing
import Foundation
@testable import Wakehold

@MainActor
struct DurationStoreTests {
    // A throwaway suite per test, so nothing touches the user's real durations.
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "wakehold-test-\(UUID().uuidString)")!
    }

    @Test func firstRunSeedsBuiltInsAndDefaultsToTwoHours() {
        let store = DurationStore(defaults: freshDefaults())
        #expect(store.durations.map(\.seconds) == WakeDuration.builtIns.map(\.seconds))
        #expect(store.defaultDuration.seconds == 7200)
    }

    @Test func addDeduplicatesBySeconds() {
        let store = DurationStore(defaults: freshDefaults())
        let before = store.durations.count
        store.add(seconds: 3600)                 // already a built-in
        #expect(store.durations.count == before)
    }

    @Test func addKeepsTheListSortedWithIndefiniteLast() {
        let store = DurationStore(defaults: freshDefaults())
        store.add(seconds: 1800)                 // 30 minutes
        let seconds = store.durations.map(\.seconds)
        #expect(seconds == [1800, 3600, 7200, 10800, nil])
    }

    @Test func removingTheDefaultReassignsIt() {
        let store = DurationStore(defaults: freshDefaults())
        let originalDefault = store.defaultID
        store.remove(originalDefault)
        #expect(store.defaultID != originalDefault)
        #expect(store.durations.contains { $0.id == store.defaultID })
    }

    @Test func removingTheDefaultHandsItToTheNextDuration() {
        let store = DurationStore(defaults: freshDefaults())
        store.add(seconds: 5400)                          // 1h 30m, between 1 hour and 2 hours
        let added = store.durations.first { $0.seconds == 5400 }!.id
        store.setDefault(added)
        store.remove(added)
        #expect(store.defaultDuration.seconds == 7200)
    }

    @Test func setDefaultOnlyAcceptsAKnownID() {
        let store = DurationStore(defaults: freshDefaults())
        let current = store.defaultID
        store.setDefault(UUID())                 // unknown id is ignored
        #expect(store.defaultID == current)
        let other = store.durations.first { $0.id != current }
        if let other {
            store.setDefault(other.id)
            #expect(store.defaultID == other.id)
        }
    }

    @Test func changesPersistAcrossInstances() {
        let defaults = freshDefaults()
        let first = DurationStore(defaults: defaults)
        first.add(seconds: 1800)
        let reloaded = DurationStore(defaults: defaults)
        #expect(reloaded.durations.contains { $0.seconds == 1800 })
    }

    @Test func restoreBuiltInsResetsTheListAndDefault() {
        let store = DurationStore(defaults: freshDefaults())
        store.add(seconds: 1800)
        store.setDefault(store.durations[0].id)
        store.restoreBuiltIns()
        #expect(store.durations.map(\.seconds) == WakeDuration.builtIns.map(\.seconds))
        #expect(store.defaultDuration.seconds == 7200)
    }
}
