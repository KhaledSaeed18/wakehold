import SwiftUI
import WakeholdKit

@main
struct WakeholdApp: App {
    @State private var controller: WakeController
    @State private var manual: ManualSessionController

    init() {
        let controller = WakeController()
        _controller = State(initialValue: controller)
        _manual = State(initialValue: ManualSessionController(wake: controller))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(controller: controller, manual: manual)
        } label: {
            Image(systemName: EyeIcon.systemImageName(isAwake: controller.isAwake))
        }
    }
}
