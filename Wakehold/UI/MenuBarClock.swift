import Foundation
import WakeholdKit

// Drives the live remaining-time shown in the menu-bar title. Runs a one-second timer only while a
// timed manual session is active, so an idle Wakehold schedules no wakeups. title is observed, so
// the MenuBarExtra label re-renders each tick (the same mechanism that updates the eye icon).
@MainActor
@Observable
final class MenuBarClock {
    private let controller: WakeController
    private(set) var title: String?
    @ObservationIgnored private var timer: Timer?

    init(controller: WakeController) {
        self.controller = controller
    }

    // Start or stop the tick based on whether a timed session is running. Driven by the manual
    // controller's onChange.
    func sync() {
        guard timedTarget() != nil else {
            timer?.invalidate()
            timer = nil
            title = nil
            return
        }
        if timer == nil {
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
            timer.tolerance = 0.2
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
        tick()
    }

    private func tick() {
        guard let target = timedTarget() else {
            sync()
            return
        }
        title = MenuBarClock.format(target.timeIntervalSinceNow)
    }

    private func timedTarget() -> Date? {
        guard let session = controller.sessions.compactMap({ $0 as? ManualSession }).first,
              let until = session.until, Date.now < until else {
            return nil
        }
        return until
    }

    static func format(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}
