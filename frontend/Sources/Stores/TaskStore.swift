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
    @Published var voiceErrorMessage: String?
    @Published var isProcessingVoice = false

    nonisolated let service: TaskService
    private let voiceCaptureService: VoiceCaptureService
    private let transcriptionService: VoiceTranscriptionService

    private var refreshTask: Task<Void, Never>?
    private var pollInterval: TimeInterval = 15
    private var pendingRecordingURL: URL?

    init(
        service: TaskService,
        voiceCaptureService: VoiceCaptureService = VoiceCaptureService(),
        transcriptionService: VoiceTranscriptionService = VoiceTranscriptionService()
    ) {
        self.service = service
        self.voiceCaptureService = voiceCaptureService
        self.transcriptionService = transcriptionService

        voiceCaptureService.levelHandler = { [weak self] level in
            guard let self else { return }
            self.voiceDraft.level = level
        }

        voiceCaptureService.completionHandler = { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let url):
                self.pendingRecordingURL = url
                Task { await self.transcribeVoice(at: url) }
            case .failure(let error):
                self.voiceErrorMessage = error.localizedDescription
                self.pendingRecordingURL = nil
            }
        }
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

    func delete(task: CodexTask) async {
        do {
            try await service.deleteTask(id: task.id)
            tasks.removeAll { $0.id == task.id }
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

    private func startPolling() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                let interval = self.pollInterval
                try? await Task.sleep(for: .seconds(interval))
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

            updatePollInterval(for: sorted)
        } catch {
            handleRefreshError(error)
        }
    }

    private func updatePollInterval(for tasks: [CodexTask]) {
        let hasActive = tasks.contains { [.queued, .running, .waitingApproval].contains($0.status) }
        pollInterval = hasActive ? 15 : 45
    }

    private func handleRefreshError(_ error: Error) {
        if let taskError = error as? TaskServiceError {
            switch taskError {
            case let .httpError(status, message) where status == 429:
                let backoff = parseRetryAfter(from: message) ?? 60
                pollInterval = max(backoff, 30)
                print("Hit rate limit, backing off polling to \(Int(pollInterval))s")
            default:
                print("Failed to refresh tasks: \(taskError.localizedDescription)")
            }
        } else {
            print("Failed to refresh tasks: \(error)")
        }
    }

    private func parseRetryAfter(from message: String?) -> TimeInterval? {
        guard let message, let data = message.data(using: .utf8) else { return nil }
        struct RateLimitPayload: Decodable { let retryAfter: TimeInterval? }
        return try? JSONDecoder().decode(RateLimitPayload.self, from: data).retryAfter
    }
}

struct VoiceDraft: Equatable {
    var transcript: String
    var level: Double
    var isRecording: Bool

    static let empty = VoiceDraft(transcript: "", level: 0, isRecording: false)
    static let recording = VoiceDraft(transcript: "", level: 0.2, isRecording: true)
}
