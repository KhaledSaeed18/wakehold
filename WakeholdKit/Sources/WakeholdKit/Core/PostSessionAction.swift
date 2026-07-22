import Foundation

// What Wakehold does when the last session ends, if the user armed something for the occasion.
public enum PostSessionAction: String, CaseIterable, Identifiable, Equatable {
    case none
    case notify
    case displaySleep
    case systemSleep
    case shutDown
    case restart

    public var id: Self { self }

    // The interrupting actions get a cancelable grace countdown before they run.
    public var needsGrace: Bool {
        switch self {
        case .systemSleep, .shutDown, .restart: true
        case .none, .notify, .displaySleep: false
        }
    }

    public var menuTitle: String {
        switch self {
        case .none: String(localized: "Nothing", bundle: .module)
        case .notify: String(localized: "Notify me", bundle: .module)
        case .displaySleep: String(localized: "Sleep the display", bundle: .module)
        case .systemSleep: String(localized: "Sleep", bundle: .module)
        case .shutDown: String(localized: "Shut down", bundle: .module)
        case .restart: String(localized: "Restart", bundle: .module)
        }
    }
}

// The side-effecting half of end actions, behind a protocol so the controller's arm and fire logic
// can be tested without sleeping or shutting anything down.
public protocol SystemActing {
    func run(_ action: PostSessionAction)
    func warn(_ message: String)
}
