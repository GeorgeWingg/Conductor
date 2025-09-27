import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: TaskStore
    var closeAction: () -> Void
    @State private var defaultApprovalMode: ApprovalMode = .autoEdit
    @State private var codexPath: String = "~/workspace/codex"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button(action: closeAction) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Task Defaults")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Picker("Approval Mode", selection: $defaultApprovalMode) {
                    ForEach(ApprovalMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("Play sound when Codex needs input", isOn: .constant(true))
                    .disabled(true)
                    .tint(.accentColor)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Codex CLI")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                HStack {
                    TextField("Path", text: $codexPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse") { }
                        .disabled(true)
                }
                Text("Set real CLI path once backend wiring is ready.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
