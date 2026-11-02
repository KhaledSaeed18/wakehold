import SwiftUI

struct ClosedLidSection: View {
    let lid: ClosedLidSettings
    @AppStorage(GuardrailKeys.holdWithLidClosed) private var holdWithLidClosed = false

    var body: some View {
        Section {
            Toggle("Stay awake with the lid closed", isOn: $holdWithLidClosed)
                .disabled(lid.isAuthorized != true)
            LabeledContent("Setup") {
                setupControl
            }
            if lid.didFail {
                Text("Setup did not finish.").foregroundStyle(.secondary)
            }
        } header: {
            Text("Lid closed")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Extends your sessions, never replaces them: sleep stays off only while a session holds. A 2-hour timer keeps a closed Mac awake for those 2 hours; a command or process, until it exits. When the last session ends, normal sleep returns and a closed Mac sleeps right away. With nothing holding, closing the lid sleeps as usual.")
                Text("Setup asks for an admin password once. A closed Mac in a bag can run hot; the battery rules still apply.")
            }
        }
        .task { lid.refresh() }
    }

    @ViewBuilder
    private var setupControl: some View {
        switch lid.isAuthorized {
        case .some(true):
            HStack {
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
                Button("Remove setup") { lid.remove() }
                    .disabled(lid.isWorking)
            }
        case .some(false):
            Button("Set up…") { lid.install() }
                .disabled(lid.isWorking)
        case .none:
            ProgressView().controlSize(.small)
        }
    }
}
