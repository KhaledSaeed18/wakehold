import Testing
import Foundation
@testable import WakeholdKit

private final class SpyActions: SystemActing {
    var ran: [PostSessionAction] = []
    var warnings: [String] = []
    func run(_ action: PostSessionAction) { ran.append(action) }
    func warn(_ message: String) { warnings.append(message) }
}

@MainActor
struct EndActionTests {
    @Test func benignActionRunsImmediately() {
        let spy = SpyActions()
        let controller = EndActionController(executor: spy, graceDuration: 60)
        controller.arm(.displaySleep)
        controller.fire()
        #expect(spy.ran == [.displaySleep])
        #expect(controller.armed == .none)          // disarmed per occasion
        #expect(controller.pending == nil)
    }

    @Test func destructiveActionWarnsThenRunsAfterGrace() async throws {
        let spy = SpyActions()
        let controller = EndActionController(executor: spy, graceDuration: 0.2)
        controller.arm(.systemSleep)
        controller.fire()
        #expect(controller.pending == .systemSleep)
        #expect(!spy.warnings.isEmpty)              // warned first
        #expect(spy.ran.isEmpty)                    // not yet
        try await pollUntil(timeout: 5) { !spy.ran.isEmpty }
        #expect(spy.ran == [.systemSleep])
        #expect(controller.pending == nil)
    }

    @Test func cancelDuringGraceStopsIt() async {
        let spy = SpyActions()
        let controller = EndActionController(executor: spy, graceDuration: 0.3)
        controller.arm(.shutDown)
        controller.fire()
        #expect(controller.pending == .shutDown)
        controller.cancelPending()
        #expect(controller.pending == nil)
        try? await Task.sleep(for: .seconds(0.5))
        #expect(spy.ran.isEmpty)                    // cancelled before it ran
    }

    @Test func fireWithNothingArmedDoesNothing() {
        let spy = SpyActions()
        let controller = EndActionController(executor: spy)
        controller.fire()
        #expect(spy.ran.isEmpty)
    }

    @Test func rearmingCancelsAPendingCountdown() {
        let spy = SpyActions()
        let controller = EndActionController(executor: spy, graceDuration: 60)
        controller.arm(.shutDown)
        controller.fire()
        #expect(controller.pending == .shutDown)
        controller.arm(.none)
        #expect(controller.pending == nil)
    }
}
