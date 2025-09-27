import SwiftUI

struct ControlStripView: View {
    @EnvironmentObject private var store: TaskStore
    @Binding var promptInput: String

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 28) {
                trafficButton(
                    color: GradientColor(base: Color(red: 0.99, green: 0.37, blue: 0.35), highlight: Color(red: 0.87, green: 0.16, blue: 0.17)),
                    icon: "text.alignleft"
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { store.openTextComposer() }
                }
                .help("Start a text task")

                trafficButton(
                    color: GradientColor(base: Color(red: 0.99, green: 0.74, blue: 0.24), highlight: Color(red: 0.95, green: 0.55, blue: 0.12)),
                    icon: "waveform"
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { store.openVoiceComposer() }
                }
                .help("Start a voice task")

                trafficButton(
                    color: GradientColor(base: Color(red: 0.27, green: 0.79, blue: 0.25), highlight: Color(red: 0.11, green: 0.58, blue: 0.22)),
                    icon: "gearshape"
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { store.toggleSettings() }
                }
                .help(store.showingSettings ? "Hide settings" : "Open settings")
            }
            .frame(maxWidth: .infinity)

            if store.showingTaskPanel {
                VStack(spacing: 18) {
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
                            withAnimation(.easeInOut) { store.toggleSettings() }
                        })
                        .environmentObject(store)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func trafficButton(color: GradientColor, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [color.base, color.highlight], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 3)
                Circle()
                    .stroke(Color.black.opacity(0.35), lineWidth: 1)
                    .blur(radius: 0.5)
                    .padding(-0.5)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .scaleEffect(1.0)
        .animation(.easeOut(duration: 0.15), value: store.composerMode)
    }

    private var textComposer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Text task")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    withAnimation(.easeInOut) { store.hideAllPanels() }
                }
                .buttonStyle(.borderless)
            }

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
                .buttonStyle(.borderedProminent)
                .disabled(promptInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(nsColor: .windowBackgroundColor).opacity(0.9)))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08))
        )
    }
}

struct VoiceComposerView: View {
    @EnvironmentObject private var store: TaskStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Voice task")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    withAnimation(.easeInOut) { store.hideAllPanels() }
                }
                .buttonStyle(.borderless)
            }

            WaveformView(level: store.voiceDraft.level)
                .frame(height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.35))
                )

            TextField("Transcript", text: Binding(
                get: { store.voiceDraft.transcript },
                set: { store.voiceDraft.transcript = $0 }
            ), axis: .vertical)
            .textFieldStyle(.roundedBorder)

            HStack {
                Button(store.voiceDraft.isRecording ? "Stop" : "Record") {
                    store.voiceDraft.isRecording.toggle()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Submit") {
                    Task {
                        await store.submitVoiceTask()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.voiceDraft.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(nsColor: .windowBackgroundColor).opacity(0.9)))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08))
        )
    }
}

struct WaveformView: View {
    var level: Double

    var body: some View {
        GeometryReader { geometry in
            let barCount = Int(max(geometry.size.width / 6, 8))
            HStack(alignment: .center, spacing: 4) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(Color.accentColor.opacity(0.7))
                        .frame(
                            width: 3,
                            height: height(for: index, total: barCount, in: geometry.size.height)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func height(for index: Int, total: Int, in maxHeight: CGFloat) -> CGFloat {
        let normalized = sin(Double(index) / Double(max(total - 1, 1)) * .pi)
        return maxHeight * CGFloat(0.35 + level * normalized)
    }
}

private struct GradientColor {
    let base: Color
    let highlight: Color
}
