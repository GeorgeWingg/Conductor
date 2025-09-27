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
    @Published var defaultApprovalMode: ApprovalMode = .autoEdit

    nonisolated let service: TaskService
    private var refreshTask: Task<Void, Never>?

    init(service: TaskService) {
        self.service = service
    }

    deinit {
        refreshTask?.cancel()
    }

    func loadInitial() async {
        guard !isLoading else { return }
        isLoading = true
        await refreshTasks()
        isLoading = false
        startPolling()
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
        selectedTaskID = nil
    }

    func submitTextTask(prompt: String) async {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            let newTask = try await service.createTextTask(prompt: prompt, approvalMode: defaultApprovalMode)
            appendOrReplace(task: newTask)
            composerMode = .none
            showingTaskPanel = true
            await refreshTasks()
        } catch {
            print("Failed to create text task: \(error)")
        }
    }

    func submitVoiceTask() async {
        guard !voiceDraft.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            let newTask = try await service.createVoiceTask(transcript: voiceDraft.transcript, approvalMode: defaultApprovalMode)
            appendOrReplace(task: newTask)
            composerMode = .none
            voiceDraft = .empty
            showingTaskPanel = true
            await refreshTasks()
        } catch {
            print("Failed to create voice task: \(error)")
        }
    }

    func approve(task: CodexTask) async {
        do {
            let updated = try await service.approveTask(id: task.id)
            appendOrReplace(task: updated)
            await refreshTasks()
        } catch {
            print("Failed to approve task: \(error)")
        }
    }

    func cancel(task: CodexTask) async {
        do {
            try await service.cancelTask(id: task.id)
            tasks.removeAll { $0.id == task.id }
            if tasks.isEmpty && composerMode == .none && !showingSettings {
                showingTaskPanel = false
            }
            await refreshTasks()
        } catch {
            print("Failed to cancel task: \(error)")
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

    private func startPolling() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                await self.refreshTasks()
            }
        }
    }

    private func refreshTasks() async {
        do {
            let fetched = try await service.fetchTasks()
            let sorted = fetched.sorted { $0.updatedAt > $1.updatedAt }
            let previousSelection = selectedTaskID
            tasks = sorted

            if !sorted.contains(where: { $0.id == previousSelection }) {
                selectedTaskID = nil
            }

            if composerMode == .none && !showingSettings {
                showingTaskPanel = !sorted.isEmpty
            }
        } catch {
            print("Failed to refresh tasks: \(error)")
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
