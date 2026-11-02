import SwiftUI
import WakeholdKit

// The menu-bar label: the eye, plus the live countdown when a timed session is running.
struct MenuBarLabel: View {
    let controller: WakeController
    let clock: MenuBarClock

    var body: some View {
        let icon = EyeIcon.imageName(isAwake: controller.isAwake)
        if let title = clock.title {
            // A menu-bar label draws only a Label's icon, so lay the countdown out explicitly.
            HStack(spacing: 4) {
                Image(icon)
                Text(verbatim: title).monospacedDigit()
            }
        } else {
            Image(icon)
        }
    }
}
