import WakeholdKit

// Ends one session from the menu by asking the coordinator that owns it, so each owner tears down
// its own watchers (the expiry timer, the workspace observer, the process source or lease) instead
// of the session vanishing from the controller underneath it.
@MainActor
struct SessionEnder {
    let manual: ManualSessionController
    let apps: AppSessionController
    let registry: SessionRegistry

    func end(_ session: any WakeSession) {
        switch session.kind {
        case .manual:
            manual.stop()
        case .app(let bundleID):
            apps.stopWatching(bundleID: bundleID)
        case .process, .port, .agent:
            registry.end(session.id)
        }
    }
}
