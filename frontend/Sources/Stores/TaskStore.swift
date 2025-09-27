import Foundation
import Combine

@MainActor
final class TaskStore: ObservableObject {
    enum ComposerMode: Equatable {
        case none
        case text
        case voice
    }

    @Published private(set) var tasks: [CodexTask] = []
    @Published var selectedTaskID: CodexTask.ID?
    @Published var composerMode: ComposerMode = .none
    @Published var showingSettings = false
    @Published var showingTaskPanel = false
    @Published var isRecordingVoice = false
    @Published var voiceDraft: VoiceDraft = .empty
    @Published var isLoading = false

    nonisolated let service: TaskService

    init(service: TaskService) {
        self.service = service
    }

    func loadInitial() async {
        guard !isLoading else { return }
        isLoading = true
        do {
            tasks = try await service.fetchTasks()
        } catch {
            print("Failed to load tasks: \(error)")
        }
        isLoading = false
    }

    func openTextComposer() {
        composerMode = .text
        voiceDraft = .empty
        showingSettings = false
        showingTaskPanel = true
    }

    func openVoiceComposer() {
        composerMode = .voice
        voiceDraft = .recording
        showingSettings = false
        showingTaskPanel = true
    }

    func toggleSettings() {
        if showingSettings {
            showingSettings = false
            if composerMode == .none && tasks.isEmpty {
                showingTaskPanel = false
            }
        } else {
            composerMode = .none
            showingSettings = true
            showingTaskPanel = true
        }
    }

    func closeComposer() {
        composerMode = .none
        voiceDraft = .empty
        if !showingSettings && tasks.isEmpty {
            showingTaskPanel = false
        }
    }

    func hideAllPanels() {
        composerMode = .none
        voiceDraft = .empty
        showingSettings = false
        showingTaskPanel = false
    }

    func submitTextTask(prompt: String) async {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            let newTask = try await service.createTextTask(prompt: prompt)
            appendOrReplace(task: newTask)
            composerMode = .none
            showingTaskPanel = true
        } catch {
            print("Failed to create text task: \(error)")
        }
    }

    func submitVoiceTask() async {
        guard !voiceDraft.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            let newTask = try await service.createVoiceTask(transcript: voiceDraft.transcript)
            appendOrReplace(task: newTask)
            composerMode = .none
            voiceDraft = .empty
            showingTaskPanel = true
        } catch {
            print("Failed to create voice task: \(error)")
        }
    }

    func update(task: CodexTask) async {
        do {
            let updated = try await service.updateTask(task)
            appendOrReplace(task: updated)
        } catch {
            print("Failed to update task: \(error)")
        }
    }

    func delete(taskID: CodexTask.ID) async {
        do {
            try await service.deleteTask(id: taskID)
            tasks.removeAll { $0.id == taskID }
            if tasks.isEmpty && composerMode == .none && !showingSettings {
                showingTaskPanel = false
            }
        } catch {
            print("Failed to delete task: \(error)")
        }
    }

    func badgeSymbolName() -> String {
        if tasks.contains(where: { $0.status == .waitingApproval }) {
            return "exclamationmark.triangle.fill"
        }
        if tasks.contains(where: { $0.status == .running || $0.status == .queued }) {
            return "bolt.fill"
        }
        return "checkmark.circle.fill"
    }

    func badgeColor() -> TaskBadgeColor {
        if tasks.contains(where: { $0.status == .waitingApproval }) {
            return .attention
        }
        if tasks.contains(where: { $0.status == .running || $0.status == .queued }) {
            return .active
        }
        return .success
    }

    private func appendOrReplace(task: CodexTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        } else {
            tasks.insert(task, at: 0)
        }
    }
}

struct VoiceDraft: Equatable {
    var transcript: String
    var level: Double
    var isRecording: Bool

    static let empty = VoiceDraft(transcript: "", level: 0, isRecording: false)
    static let recording = VoiceDraft(transcript: "", level: 0.2, isRecording: true)
}
