import Foundation

// Owns the single manual/duration session and its expiry. The menu drives this; it in turn
// drives WakeController through add/remove, so the controller never learns about manual timers.
// This is the Phase 0 stand-in for the Phase 2 SessionRegistry (ADR-016).
@MainActor
public final class ManualSessionController {
    private let wake: WakeController
    private var currentID: UUID?
    private var expiry: Task<Void, Never>?

    // Fired after the manual session starts, stops, or expires, so the UI can update its clock.
    public var onChange: (@MainActor () -> Void)?

    public init(wake: WakeController) {
        self.wake = wake
    }

    // Manual is a single toggle: a new choice replaces any running manual session. seconds nil
    // means indefinite.
    public func start(label: String, seconds: TimeInterval?) {
        start(ManualSession(label: label, seconds: seconds))
    }

    // Start a pre-built session. The shape future session sources will use, and the seam tests
    // use to inject a near-instant target.
    func start(_ session: ManualSession) {
        clear()
        currentID = session.id
        wake.add(session)
        scheduleExpiry(for: session)
        onChange?()
    }

    public func stop() {
        clear()
        onChange?()
    }

    // Whether a manual session is currently running, for the toggle hotkey.
    public var isRunning: Bool { currentID != nil }

    private func clear() {
        expiry?.cancel()
        expiry = nil
        if let id = currentID {
            wake.remove(id)
            currentID = nil
        }
    }

    // Anchor removal to the absolute target date, not an accumulated countdown. isActive already
    // guarantees correctness; this timer just nudges the controller to release near the target.
    private func scheduleExpiry(for session: ManualSession) {
        guard let until = session.until else { return }        // indefinite never expires
        let id = session.id
        expiry = Task { [weak self] in
            let seconds = until.timeIntervalSinceNow
            if seconds > 0 {
                try? await Task.sleep(for: .seconds(seconds))
            }
            guard !Task.isCancelled else { return }
            self?.expire(id)
        }
    }

    private func expire(_ id: UUID) {
        guard currentID == id else { return }
        wake.remove(id)
        currentID = nil
        expiry = nil
        onChange?()
    }
}
