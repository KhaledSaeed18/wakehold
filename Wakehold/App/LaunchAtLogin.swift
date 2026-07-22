import ServiceManagement
import Observation
import WakeholdKit

enum LaunchKeys {
    // Whether opening Wakehold also opens a hold with the default duration. Distinct from the login
    // item: this governs what the app does on launch, not whether it launches. Unset reads false.
    static let activateOnLaunch = "activateOnLaunch"
}

// Wraps the login-item registration for the main app. isEnabled mirrors the system's actual
// status, so the Settings toggle always reflects reality even if registration is refused (an
// unsigned or non-installed build cannot register a login item).
@MainActor
@Observable
final class LaunchAtLogin {
    private(set) var isEnabled: Bool = false
    private let log = Log.make("LaunchAtLogin")

    init() {
        refresh()
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log.error("login item \(enabled ? "register" : "unregister", privacy: .public) failed: \(String(describing: error), privacy: .public)")
        }
        refresh()
    }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
