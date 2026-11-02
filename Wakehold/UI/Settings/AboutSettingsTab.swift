import SwiftUI

struct AboutSettingsTab: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }

    var body: some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private func link(_ title: LocalizedStringKey, _ address: String) -> some View {
        if let url = URL(string: address) {
            Link(title, destination: url)
        }
    }
}
