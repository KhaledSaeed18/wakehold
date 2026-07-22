import Foundation
import Observation
import WakeholdKit

// Watches every other process that is holding the Mac awake and exposes it for the menu. Read-only:
// it never touches the assertion, and views read `holds` without importing IOKit. There is no push
// notification for system assertions (the power-management Darwin keys do not post), so it polls
// coarsely, the same shape as the port poll, and publishes only when the set actually changes.
@MainActor
@Observable
final class AssertionInspector {
    private(set) var holds: [ProcessHold] = []

    private let interval: TimeInterval
    private let reader: @MainActor () -> [ProcessHold]
    @ObservationIgnored private var timer: DispatchSourceTimer?

    // reader is injectable so tests drive it without live IOKit; the default drops our own pid so the
    // menu never lists Wakehold's own hold, which it already shows.
    init(interval: TimeInterval = 5, reader: (@MainActor () -> [ProcessHold])? = nil) {
        self.interval = interval
        if let reader {
            self.reader = reader
        } else {
            let ownPID = ProcessInfo.processInfo.processIdentifier
            self.reader = { SystemAssertions.currentHolds(excluding: ownPID) }
        }
    }

    func start() {
        guard timer == nil else { return }
        refresh()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.refresh() }
        }
        self.timer = timer
        timer.resume()
    }

    private func refresh() {
        let next = reader()
        if next != holds { holds = next }
    }

    deinit {
        timer?.cancel()
    }
}
