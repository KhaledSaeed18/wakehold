import Foundation

// Glue between the control endpoint (and tests) and the WakeController. Creates watcher-backed
// sessions, owns their liveness sources, and removes them when the watched thing goes away. The
// controller stays generic; the registry is where per-source lifecycle lives.
@MainActor
public final class SessionRegistry {
    private let wake: WakeController
    private let portPollInterval: TimeInterval
    private var processSources: [UUID: DispatchSourceProcess] = [:]
    private var portSessions: [UUID: PortSession] = [:]
    private var portTimer: DispatchSourceTimer?
    private var leaseTTL: [UUID: TimeInterval] = [:]
    private var leaseTasks: [UUID: Task<Void, Never>] = [:]

    public init(wake: WakeController, portPollInterval: TimeInterval = 10) {
        self.wake = wake
        self.portPollInterval = portPollInterval
    }

    // MARK: Process

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

    // MARK: Port

    public func startPort(_ port: UInt16, label: String) -> UUID {
        let session = PortSession(port: port, label: label, isListening: isPortListening(port))
        portSessions[session.id] = session
        wake.add(session)
        startPollingIfNeeded()
        return session.id
    }

    private func startPollingIfNeeded() {
        guard portTimer == nil, !portSessions.isEmpty else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + portPollInterval, repeating: portPollInterval)
        timer.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.pollPorts() }
        }
        portTimer = timer
        timer.resume()
    }

    private func pollPorts() {
        // Snapshot so mutating portSessions during the loop is safe.
        for (id, session) in portSessions {
            let listening = isPortListening(session.port)
            guard listening != session.isListening else { continue }
            var updated = session
            updated.isListening = listening
            portSessions[id] = updated
            wake.update(updated)
        }
    }

    private func stopPollingIfIdle() {
        guard portSessions.isEmpty else { return }
        portTimer?.cancel()
        portTimer = nil
    }

    // MARK: Agent leases

    // Open an agent lease that holds for ttl seconds unless renewed.
    public func startAgent(label: String, ttl: TimeInterval) -> UUID {
        let session = AgentSession(label: label)
        let id = session.id
        leaseTTL[id] = ttl
        wake.add(session)
        scheduleLeaseExpiry(id)
        return id
    }

    // Reset a lease's TTL clock. Returns false if the id is not a known lease.
    public func renew(_ id: UUID) -> Bool {
        guard leaseTTL[id] != nil else { return false }
        scheduleLeaseExpiry(id)
        return true
    }

    private func scheduleLeaseExpiry(_ id: UUID) {
        leaseTasks[id]?.cancel()
        guard let ttl = leaseTTL[id] else { return }
        leaseTasks[id] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(ttl))
            guard !Task.isCancelled else { return }
            self?.expireLease(id)
        }
    }

    private func expireLease(_ id: UUID) {
        guard leaseTTL[id] != nil else { return }
        leaseTasks[id] = nil
        leaseTTL[id] = nil
        wake.remove(id)
    }

    // MARK: Lifecycle

    // Remove a session by id. Idempotent across every source type.
    public func end(_ id: UUID) {
        cancelSource(id)
        if portSessions.removeValue(forKey: id) != nil {
            stopPollingIfIdle()
        }
        leaseTasks.removeValue(forKey: id)?.cancel()
        leaseTTL.removeValue(forKey: id)
        wake.remove(id)
    }

    // End every session this registry owns (process, port, agent). The manual timer is separate.
    public func endAll() {
        let ids = Set(processSources.keys).union(portSessions.keys).union(leaseTTL.keys)
        for id in ids {
            end(id)
        }
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
        portTimer?.cancel()
        for task in leaseTasks.values {
            task.cancel()
        }
    }
}
