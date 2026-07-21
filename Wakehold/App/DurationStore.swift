import Foundation
import Observation

// The user's editable list of durations plus the one the toggle hotkey uses. Persisted to
// UserDefaults, seeded with the built-ins on first run.
@MainActor
@Observable
final class DurationStore {
    private(set) var durations: [WakeDuration]
    private(set) var defaultID: WakeDuration.ID

    private let durationsKey = "wakeDurations"
    private let defaultKey = "defaultDurationID"

    init() {
        let defaults = UserDefaults.standard
        let list: [WakeDuration]
        if let data = defaults.data(forKey: durationsKey),
           let saved = try? JSONDecoder().decode([WakeDuration].self, from: data), !saved.isEmpty {
            list = saved
        } else {
            list = WakeDuration.builtIns
        }
        let stored = defaults.string(forKey: defaultKey).flatMap(UUID.init(uuidString:))
        if let stored, list.contains(where: { $0.id == stored }) {
            defaultID = stored
        } else {
            defaultID = (list.first { $0.seconds == 7200 } ?? list.first)?.id ?? UUID()
        }
        durations = list
        persist()
    }

    var defaultDuration: WakeDuration {
        durations.first { $0.id == defaultID } ?? durations.first ?? WakeDuration(seconds: 7200)
    }

    func add(seconds: TimeInterval) {
        guard seconds > 0, !durations.contains(where: { $0.seconds == seconds }) else { return }
        durations.append(WakeDuration(seconds: seconds))
        durations.sort { ($0.seconds ?? .greatestFiniteMagnitude) < ($1.seconds ?? .greatestFiniteMagnitude) }
        persist()
    }

    func remove(_ id: WakeDuration.ID) {
        durations.removeAll { $0.id == id }
        if defaultID == id { defaultID = durations.first?.id ?? defaultID }
        persist()
    }

    func setDefault(_ id: WakeDuration.ID) {
        guard durations.contains(where: { $0.id == id }) else { return }
        defaultID = id
        persist()
    }

    private func persist() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(durations) {
            defaults.set(data, forKey: durationsKey)
        }
        defaults.set(defaultID.uuidString, forKey: defaultKey)
    }
}
