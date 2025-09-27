import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: TaskStore
    @State private var defaultApprovalMode: ApprovalMode = .autoEdit
    @State private var codexPath: String = "~/workspace/codex"

    var body: some View {
        Form {
            Section("Task Defaults") {
                Picker("Approval Mode", selection: $defaultApprovalMode) {
                    ForEach(ApprovalMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                Toggle("Play sound when Codex needs input", isOn: .constant(true))
                    .disabled(true)
            }

            Section("Codex CLI") {
                HStack {
                    TextField("Path", text: $codexPath)
                    Button("Browse") { }
                        .disabled(true)
                }
                Text("Configure actual CLI path once backend wiring is ready.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 320, height: 220)
        .padding(20)
    }
}
