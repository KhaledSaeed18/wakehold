import Foundation

// Glue between the control endpoint (and tests) and the WakeController. Creates watcher-backed
// sessions, owns their liveness sources, and removes them when the watched thing goes away. The
// controller stays generic; the registry is where per-source lifecycle lives.
@MainActor
public final class SessionRegistry {
    private let wake: WakeController
    private var processSources: [UUID: DispatchSourceProcess] = [:]

    public init(wake: WakeController) {
        self.wake = wake
    }

    // Start watching a live process. Returns the session id, or nil if the pid is not alive.
    public func startProcess(pid: pid_t, label: String) -> UUID? {
        guard let startTime = processStartTime(pid: pid) else { return nil }
        let session = ProcessSession(pid: pid, label: label, startTime: startTime)
        let id = session.id

        let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: .main)
        source.setEventHandler { [weak self] in
            // The source fires on the main queue, which is the main actor's executor.
            MainActor.assumeIsolated { self?.handleExit(id) }
        }
        processSources[id] = source
        wake.add(session)
        source.resume()

        // Creation race: the process may have exited between the start-time capture and arming,
        // in which case the source never fires. Re-check and clean up.
        guard processExists(pid: pid) else {
            handleExit(id)
            return nil
        }
        return id
    }

    // Remove a session by id. Idempotent.
    public func end(_ id: UUID) {
        cancelSource(id)
        wake.remove(id)
    }

    private func handleExit(_ id: UUID) {
        cancelSource(id)
        wake.remove(id)
    }

    private func cancelSource(_ id: UUID) {
        processSources.removeValue(forKey: id)?.cancel()
    }

    deinit {
        for source in processSources.values {
            source.cancel()
        }
    }
}
