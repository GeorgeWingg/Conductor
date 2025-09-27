import SwiftUI

struct ControlStripView: View {
    @EnvironmentObject private var store: TaskStore
    @Binding var promptInput: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                circleButton(systemName: "plus") {
                    withAnimation(.easeInOut) { store.openTextComposer() }
                }
                circleButton(systemName: "mic.fill") {
                    withAnimation(.easeInOut) { store.openVoiceComposer() }
                }
                circleButton(systemName: "gearshape.fill") {
                    withAnimation(.easeInOut) { store.toggleSettings() }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            switch store.composerMode {
            case .none:
                EmptyView()
            case .text:
                textComposer
            case .voice:
                VoiceComposerView()
            }

            if store.showingSettings {
                SettingsView(closeAction: {
                    withAnimation(.easeInOut) { store.showingSettings = false }
                })
                .environmentObject(store)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func circleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(.white)
                .background(
                    Circle()
                        .fill(Color.accentColor)
                )
        }
        .buttonStyle(.plain)
        .help(helpText(for: systemName))
    }

    private func helpText(for systemName: String) -> String {
        switch systemName {
        case "plus": return "Start a text task"
        case "mic.fill": return "Start a voice task"
        case "gearshape.fill": return store.showingSettings ? "Hide settings" : "Open settings"
        default: return ""
        }
    }

    private var textComposer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Task prompt")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Type task details here", text: $promptInput, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Create Task") {
                    Task {
                        let prompt = promptInput
                        promptInput = ""
                        await store.submitTextTask(prompt: prompt)
                    }
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(promptInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct VoiceComposerView: View {
    @EnvironmentObject private var store: TaskStore
    @State private var liveTranscript: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Voice capture")
                .font(.caption)
                .foregroundStyle(.secondary)
            WaveformView(level: store.voiceDraft.level)
                .frame(height: 36)
            TextField("Transcript", text: Binding(
                get: { store.voiceDraft.transcript },
                set: { store.voiceDraft.transcript = $0 }
            ), axis: .vertical)
            .textFieldStyle(.roundedBorder)
            HStack {
                Button(store.voiceDraft.isRecording ? "Stop" : "Record") {
                    store.voiceDraft.isRecording.toggle()
                }
                Spacer()
                Button("Submit") {
                    Task {
                        await store.submitVoiceTask()
                    }
                }
                .disabled(store.voiceDraft.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct WaveformView: View {
    var level: Double

    var body: some View {
        GeometryReader { geometry in
            let barCount = Int(geometry.size.width / 6)
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(Color.accentColor.opacity(0.6))
                        .frame(
                            width: 3,
                            height: height(for: index, total: barCount, in: geometry.size.height)
                        )
                }
            }
        }
    }

    private func height(for index: Int, total: Int, in maxHeight: CGFloat) -> CGFloat {
        let normalized = sin(Double(index) / Double(max(total, 1)) * .pi)
        return maxHeight * CGFloat(level + (1 - level) * normalized)
    }
}
