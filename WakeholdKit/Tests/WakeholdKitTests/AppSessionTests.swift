import Testing
@testable import WakeholdKit

struct AppSessionTests {
    @Test func isActiveFollowsRunning() {
        var session = AppSession(bundleID: "com.apple.dt.Xcode", label: "Xcode", isRunning: true)
        #expect(session.isActive)
        session.isRunning = false
        #expect(!session.isActive)
    }

    @Test func kindCarriesBundleID() {
        let session = AppSession(bundleID: "com.foo.bar", label: "Foo", isRunning: true)
        guard case .app(let bundleID) = session.kind else {
            Issue.record("expected an app kind")
            return
        }
        #expect(bundleID == "com.foo.bar")
        #expect(session.kind.name == "app")
    }
}
