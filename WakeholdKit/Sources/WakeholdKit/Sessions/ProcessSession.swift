import Foundation
import Darwin

// Awake while a specific process is alive. Liveness is event-driven (the registry arms a
// DispatchSource on the pid) with isActive as a correctness backstop. The captured start time
// guards against PID reuse: a recycled pid reports a different start time and reads inactive.
public struct ProcessSession: WakeSession {
    public let id = UUID()
    public let pid: pid_t
    public let label: String
    let startTime: UInt64

    public var kind: SessionKind { .process(pid: pid) }

    public var isActive: Bool {
        processStartTime(pid: pid) == startTime
    }
}

// Process start time in seconds since the epoch, or nil if no such process exists (or it is not
// inspectable, e.g. owned by another user). The same-user processes we watch are visible.
func processStartTime(pid: pid_t) -> UInt64? {
    var info = proc_bsdinfo()
    let size = Int32(MemoryLayout<proc_bsdinfo>.size)
    let read = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size)
    guard read == size else { return nil }
    return UInt64(info.pbi_start_tvsec)
}

func processExists(pid: pid_t) -> Bool {
    processStartTime(pid: pid) != nil
}
