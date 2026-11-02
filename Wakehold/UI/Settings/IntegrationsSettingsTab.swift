import SwiftUI

struct IntegrationsSettingsTab: View {
    let integrations: IntegrationStatus

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    if let path = integrations.cliPath {
                        Text(verbatim: path).font(.system(.callout, design: .monospaced))
                    } else {
                        Text("Not installed")
                    }
                } label: {
                    Text(verbatim: "wakehold").font(.system(.body, design: .monospaced))
                }
                CommandRow(command: "wakehold -- pnpm build", note: "Hold while a command runs", integrations: integrations)
                CommandRow(command: "wakehold --keep :3000", note: "Hold while a port listens", integrations: integrations)
                CommandRow(command: "wakehold status", note: "Show what is holding", integrations: integrations)
            } header: {
                Text("Command line")
            } footer: {
                if integrations.cliPath == nil {
                    Text("Build the CLI from the repository and link it onto your PATH, as the README shows.")
                }
            }

            Section {
                LabeledContent("Status") {
                    if integrations.isClaudeCodeConnected {
                        Label("Connected", systemImage: "checkmark.circle.fill")
                    } else {
                        Text("Not connected")
                    }
                }
                LabeledContent("Hooks config") {
                    Button("Copy") { integrations.copy(IntegrationStatus.claudeHooksConfig) }
                }
            } header: {
                Text(verbatim: "Claude Code")
            } footer: {
                Text("Paste the hooks config into ~/.claude/settings.json. An agent's lease expires on its own if it exits without ending.")
            }

            Section {
                CommandRow(command: "wakehold hook start", note: "On session start", integrations: integrations)
                CommandRow(command: "wakehold hook renew", note: "On each action or turn end", integrations: integrations)
                CommandRow(command: "wakehold hook end", note: "On session end", integrations: integrations)
            } header: {
                Text("Other agents")
            } footer: {
                Text("Codex CLI, Gemini CLI, and Cursor: point each tool's hooks at these commands.")
            }

            Section {
                LabeledContent("Socket") {
                    Text(verbatim: integrations.socketPath)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("Control endpoint")
            } footer: {
                Text("A Unix socket readable only by you. Scripts can open sessions with curl --unix-socket.")
            }
        }
        .formStyle(.grouped)
        .onAppear { integrations.refresh() }
    }
}

private struct CommandRow: View {
    let command: String
    let note: LocalizedStringKey
    let integrations: IntegrationStatus

    var body: some View {
        LabeledContent {
            Button {
                integrations.copy(command)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copy")
        } label: {
            Text(verbatim: command).font(.system(.callout, design: .monospaced))
            Text(note)
        }
    }
}
