import SwiftUI

struct DurationsSettingsTab: View {
    let durations: DurationStore
    @State private var hours = 1
    @State private var minutes = 0

    var body: some View {
        Form {
            Section {
                Picker("Default", selection: Binding(
                    get: { durations.defaultID },
                    set: { durations.setDefault($0) }
                )) {
                    ForEach(durations.durations) { duration in
                        Text(duration.label).tag(duration.id)
                    }
                }
            } footer: {
                Text("A click on the eye, the toggle shortcut, and activate on launch use the default.")
            }

            Section {
                ForEach(durations.durations) { duration in
                    row(duration)
                }
                Button("Restore defaults") { durations.restoreBuiltIns() }
                    .buttonStyle(.link)
            } header: {
                Text("Quick picks")
            } footer: {
                Text("These appear in the menu.")
            }

            Section("Add a duration") {
                LabeledContent("Length") {
                    HStack(spacing: 6) {
                        Text("\(hours) h").monospacedDigit()
                        Stepper("\(hours) h", value: $hours, in: 0...23).labelsHidden()
                        Text("\(minutes) m").monospacedDigit().padding(.leading, 8)
                        Stepper("\(minutes) m", value: $minutes, in: 0...55, step: 5).labelsHidden()
                        Button("Add") {
                            durations.add(seconds: TimeInterval(hours * 3600 + minutes * 60))
                        }
                        .disabled(hours == 0 && minutes == 0)
                        .padding(.leading, 8)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func row(_ duration: WakeDuration) -> some View {
        HStack {
            Text(duration.label)
            if duration.id == durations.defaultID {
                Text("Default")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                durations.remove(duration.id)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help("Remove")
            .disabled(durations.durations.count <= 1)
        }
    }
}
