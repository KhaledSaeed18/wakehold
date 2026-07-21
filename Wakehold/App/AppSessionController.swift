import AppKit
import Observation
import WakeholdKit

struct RunningApp: Identifiable {
    let bundleID: String
    let name: String
    var id: String { bundleID }
}

// Watches GUI apps by bundle id via NSWorkspace and drives the WakeController. AppKit lives here,
// in the app, so the kit and the CLI never link it.
@MainActor
@Observable
final class AppSessionController {
    private let wake: WakeController
    private var sessions: [String: AppSession] = [:]          // bundleID -> session
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init(wake: WakeController) {
        self.wake = wake
    }

    var watchedBundleIDs: Set<String> { Set(sessions.keys) }

    // Running, ordinary (Dock-visible) apps, deduplicated and sorted, for the menu.
    func runningApps() -> [RunningApp] {
        var seen = Set<String>()
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> RunningApp? in
                guard let bundleID = app.bundleIdentifier, seen.insert(bundleID).inserted else { return nil }
                return RunningApp(bundleID: bundleID, name: app.localizedName ?? bundleID)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func toggle(bundleID: String, name: String) {
        if let session = sessions[bundleID] {
            wake.remove(session.id)
            sessions[bundleID] = nil
            stopObservingIfIdle()
        } else {
            let session = AppSession(bundleID: bundleID, label: name, isRunning: isRunning(bundleID))
            sessions[bundleID] = session
            wake.add(session)
            startObserving()
        }
    }

    private func isRunning(_ bundleID: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleID }
    }

    private func startObserving() {
        guard observers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        observers = [
            center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] note in
                MainActor.assumeIsolated { self?.appChanged(note, running: true) }
            },
            center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
                MainActor.assumeIsolated { self?.appChanged(note, running: false) }
            }
        ]
    }

    private func appChanged(_ note: Notification, running: Bool) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier,
              var session = sessions[bundleID], session.isRunning != running else {
            return
        }
        session.isRunning = running
        sessions[bundleID] = session
        wake.update(session)
    }

    private func stopObservingIfIdle() {
        guard sessions.isEmpty, !observers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach { center.removeObserver($0) }
        observers = []
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach { center.removeObserver($0) }
    }
}
