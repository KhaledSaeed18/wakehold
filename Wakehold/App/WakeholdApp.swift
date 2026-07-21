import SwiftUI

@main
struct WakeholdApp: App {
    @State private var controller = WakeController()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(controller: controller)
        } label: {
            Image(systemName: EyeIcon.systemImageName(isAwake: controller.isAwake))
        }
    }
}
