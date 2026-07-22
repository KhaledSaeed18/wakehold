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

    // Localized: plural agreement (English "1 minute"/"5 minutes", Arabic's six forms) lives in the
    // String Catalog, so this drops the manual singular check and reads through String(localized:).
    var label: String {
        guard let seconds else { return String(localized: "Indefinite") }
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        switch (hours, minutes) {
        case (0, let m): return String(localized: "\(m) minutes")
        case (let h, 0): return String(localized: "\(h) hours")
        case (let h, let m): return String(localized: "\(h)h \(m)m")
        }
    }

    static let builtIns: [WakeDuration] = [
        WakeDuration(seconds: 3600),
        WakeDuration(seconds: 7200),
        WakeDuration(seconds: 10800),
        WakeDuration(seconds: nil),
    ]
}
