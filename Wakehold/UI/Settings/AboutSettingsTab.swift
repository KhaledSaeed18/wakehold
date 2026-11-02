import SwiftUI

struct AboutSettingsTab: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }

    var body: some View {
        // A scroll view like the form panes: a bare stack filling the detail column left the split
        // view's sidebar list blank.
        ScrollView {
            content
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
                .padding(.horizontal)
        }
    }

    private var content: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
            Text(verbatim: "Wakehold")
                .font(.title.weight(.semibold))
            Text("Holds. Then lets go.")
                .foregroundStyle(.secondary)
            Text("Version \(version)")
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            Text("Wakehold keeps your Mac awake for exactly as long as your work is alive, then lets it sleep. A timer, a running process, a listening port, a wrapped command, an agent session, or an open app: each one is a session that holds the Mac awake. When the last session ends, the hold releases on its own.")
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 440)
                .padding(.top, 12)
            Text("The menu bar, the wakehold command, and any agent or script all open sessions through the same local endpoint.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 440)

            HStack(spacing: 16) {
                link("Source code", "https://github.com/KhaledSaeed18/wakehold")
                link("Report an issue", "https://github.com/KhaledSaeed18/wakehold/issues")
                link("License", "https://github.com/KhaledSaeed18/wakehold/blob/main/LICENSE")
            }
            .padding(.top, 8)

            Text("MIT License")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func link(_ title: LocalizedStringKey, _ address: String) -> some View {
        if let url = URL(string: address) {
            Link(title, destination: url)
        }
    }
}
