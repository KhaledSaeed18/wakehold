import SwiftUI

// The panes in the settings sidebar, in display order.
enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case durations
    case power
    case integrations
    case about

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .general: "General"
        case .durations: "Durations"
        case .power: "Power"
        case .integrations: "Integrations"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .durations: "timer"
        case .power: "bolt"
        case .integrations: "terminal"
        case .about: "info.circle"
        }
    }
}
