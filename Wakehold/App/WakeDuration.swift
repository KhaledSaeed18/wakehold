import Foundation

// A keep-awake duration: a number of seconds, or nil for indefinite. The label is derived, so a
// custom duration is just its time. Codable so the user's list persists.
struct WakeDuration: Codable, Identifiable, Equatable {
    let id: UUID
    let seconds: TimeInterval?          // nil = indefinite

    init(id: UUID = UUID(), seconds: TimeInterval?) {
        self.id = id
        self.seconds = seconds
    }

    var label: String {
        guard let seconds else { return "Indefinite" }
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        switch (hours, minutes) {
        case (0, let m): return m == 1 ? "1 minute" : "\(m) minutes"
        case (let h, 0): return h == 1 ? "1 hour" : "\(h) hours"
        case (let h, let m): return "\(h)h \(m)m"
        }
    }

    static let builtIns: [WakeDuration] = [
        WakeDuration(seconds: 3600),
        WakeDuration(seconds: 7200),
        WakeDuration(seconds: 10800),
        WakeDuration(seconds: nil),
    ]
}
