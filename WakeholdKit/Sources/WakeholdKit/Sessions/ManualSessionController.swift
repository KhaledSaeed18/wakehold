import Foundation

// Owns the single manual/duration session and its expiry. The menu drives this; it in turn
// drives WakeController through add/remove, so the controller never learns about manual timers.
// This is the Phase 0 stand-in for the Phase 2 SessionRegistry (ADR-016).
@MainActor
public final class ManualSessionController {
    private let wake: WakeController
    private var currentID: UUID?
    private var expiry: Task<Void, Never>?

    public init(wake: WakeController) {
        self.wake = wake
    }

    // Manual is a single toggle: a new choice replaces any running manual session.
    public func start(_ duration: ManualDuration) {
        start(ManualSession(duration: duration))
    }

    // Start a pre-built session. The shape future session sources will use, and the seam tests
    // use to inject a near-instant target.
    func start(_ session: ManualSession) {
        stop()
        currentID = session.id
        wake.add(session)
        scheduleExpiry(for: session)
    }

    public func stop() {
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
    }
}
