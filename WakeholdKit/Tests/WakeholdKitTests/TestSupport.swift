import Foundation

// Await until a condition holds or the timeout elapses, yielding the main actor between checks so
// dispatch-source and timer handlers get a chance to run.
@MainActor
func pollUntil(timeout: TimeInterval, _ condition: () -> Bool) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return }
        try await Task.sleep(for: .milliseconds(50))
    }
}
