import Foundation

// Runs an armed post-session action once when the last session ends, with a cancelable grace
// countdown before the interrupting ones. Armed per occasion: it fires once then disarms (ADR-014).
@MainActor
@Observable
public final class EndActionController {
    public private(set) var armed: PostSessionAction = .none
    public private(set) var pending: PostSessionAction?

    private let executor: SystemActing
    private let graceDuration: TimeInterval
    private var graceTask: Task<Void, Never>?

    public init(executor: SystemActing = SystemActions(), graceDuration: TimeInterval = 60) {
        self.executor = executor
        self.graceDuration = graceDuration
    }

    public func arm(_ action: PostSessionAction) {
        cancelPending()
        armed = action
    }

    // Call when the last active session ends.
    public func fire() {
        guard armed != .none else { return }
        let action = armed
        armed = .none
        guard action.needsGrace else {
            executor.run(action)
            return
        }
        pending = action
        executor.warn("Wakehold will \(action.menuTitle.lowercased()) in \(Int(graceDuration))s. Open the menu to cancel.")
        graceTask = Task { [weak self, graceDuration] in
            try? await Task.sleep(for: .seconds(graceDuration))
            guard !Task.isCancelled else { return }
            self?.execute(action)
        }
    }

    public func cancelPending() {
        graceTask?.cancel()
        graceTask = nil
        pending = nil
    }

    private func execute(_ action: PostSessionAction) {
        graceTask = nil
        pending = nil
        executor.run(action)
    }
}
