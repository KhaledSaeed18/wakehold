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
            Text("Turns system sleep off while a session holds, so closing the lid does not sleep the Mac. Setup asks for an admin password once. A closed Mac in a bag can run hot; the battery rules still apply.")
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
