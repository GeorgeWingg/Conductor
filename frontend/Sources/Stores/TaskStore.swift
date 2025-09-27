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
    @Published private(set) var taskLogs: [CodexTask.ID: [TaskEvent]] = [:]
    @Published var voiceErrorMessage: String?
    @Published var isProcessingVoice = false

    nonisolated let service: TaskService
    private let voiceCaptureService: VoiceCaptureService
    private let transcriptionService: VoiceTranscriptionService

    private let activePollInterval: TimeInterval = 30
    private let idlePollInterval: TimeInterval = 120
    private let minimumRefreshSpacing: TimeInterval = 5

    private var refreshTask: Task<Void, Never>?
    private var pollInterval: TimeInterval
    private var lastRefreshDate: Date?
    private var nextAllowedRefresh: Date?
    private var isRefreshing = false
    private var pendingForcedRefresh = false
    private var rateLimitRetryTask: Task<Void, Never>?
    private var pendingRecordingURL: URL?
    private var voiceTranscriptionTask: Task<Void, Never>?

    init(
        service: TaskService,
        voiceCaptureService: VoiceCaptureService = VoiceCaptureService(),
        transcriptionService: VoiceTranscriptionService = VoiceTranscriptionService()
    ) {
        self.service = service
        self.voiceCaptureService = voiceCaptureService
        self.transcriptionService = transcriptionService
        self.pollInterval = activePollInterval

        voiceCaptureService.levelHandler = { [weak self] level in
            guard let self else { return }
            self.voiceDraft.level = level
        }

        voiceCaptureService.completionHandler = { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let url):
                self.pendingRecordingURL = url
                self.voiceTranscriptionTask?.cancel()
                self.voiceTranscriptionTask = Task { [weak self] in
                    await self?.transcribeVoice(at: url)
                }
            case .failure(let error):
                if let captureError = error as? VoiceCaptureService.VoiceCaptureError,
                   captureError == .cancelled {
                    self.voiceErrorMessage = nil
                } else {
                    self.voiceErrorMessage = error.localizedDescription
                }
                self.pendingRecordingURL = nil
            }
        }
    }

    deinit {
        refreshTask?.cancel()
        voiceTranscriptionTask?.cancel()
        rateLimitRetryTask?.cancel()
    }

    func loadInitial() async {
        guard !isLoading else { return }
        isLoading = true
        await refreshTasks(force: true)
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
        voiceDraft = .empty
        voiceErrorMessage = nil
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
        voiceErrorMessage = nil
        cancelVoiceCapture()
        if !showingSettings && tasks.isEmpty {
            showingTaskPanel = false
        }
    }

    func hideAllPanels() {
        composerMode = .none
        voiceDraft = .empty
        voiceErrorMessage = nil
        showingSettings = false
        showingTaskPanel = false
        selectedTaskID = nil
        cancelVoiceCapture()
    }

    func toggleVoiceRecording() {
        if voiceCaptureService.isRecording {
            stopVoiceRecording()
        } else {
            Task { await startVoiceRecording() }
        }
    }

    func submitTextTask(prompt: String) async {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            let newTask = try await service.createTextTask(prompt: prompt, approvalMode: defaultApprovalMode)
            appendOrReplace(task: newTask)
            composerMode = .none
            showingTaskPanel = true
            await refreshTasks(force: true)
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
            voiceErrorMessage = nil
            showingTaskPanel = true
            await refreshTasks(force: true)
        } catch {
            print("Failed to create voice task: \(error)")
        }
    }

    private func startVoiceRecording() async {
        guard !voiceCaptureService.isRecording else { return }
        voiceErrorMessage = nil

        do {
            try await voiceCaptureService.startRecording()
            voiceDraft = .recording
            isRecordingVoice = true
        } catch {
            voiceDraft = .empty
            voiceErrorMessage = error.localizedDescription
            isRecordingVoice = false
        }
    }

    private func stopVoiceRecording() {
        guard voiceCaptureService.isRecording else { return }
        voiceCaptureService.stopRecording()
        isRecordingVoice = false
        voiceDraft.isRecording = false
    }

    private func cancelVoiceCapture() {
        if voiceCaptureService.isRecording {
            voiceCaptureService.cancelRecording()
        }

        if let url = pendingRecordingURL {
            try? FileManager.default.removeItem(at: url)
            pendingRecordingURL = nil
        }

        voiceTranscriptionTask?.cancel()
        voiceTranscriptionTask = nil
        isProcessingVoice = false
        isRecordingVoice = false
        voiceDraft = .empty
    }

    private func transcribeVoice(at url: URL) async {
        if Task.isCancelled { return }
        isProcessingVoice = true
        voiceErrorMessage = nil

        defer {
            isProcessingVoice = false
            try? FileManager.default.removeItem(at: url)
            if pendingRecordingURL == url {
                pendingRecordingURL = nil
            }
        }

        do {
            let transcript = try await transcriptionService.transcribeAudio(fileURL: url)
            if Task.isCancelled { return }
            voiceDraft.transcript = transcript
        } catch is CancellationError {
            return
        } catch {
            voiceErrorMessage = error.localizedDescription
        }
    }

    func approve(task: CodexTask) async {
        do {
            let updated = try await service.approveTask(id: task.id)
            appendOrReplace(task: updated)
            await refreshTasks(force: true)
        } catch {
            print("Failed to approve task: \(error)")
        }
    }

    func cancel(task: CodexTask) async {
        do {
            try await service.cancelTask(id: task.id)
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                var updated = tasks[index]
                updated.status = .failed
                updated.currentStep = "Cancellation requested..."
                updated.needsAttention = false
                tasks[index] = updated
            }
            await refreshTasks(force: true)
        } catch {
            print("Failed to cancel task: \(error)")
        }
    }

    func delete(task: CodexTask) async {
        do {
            try await service.deleteTask(id: task.id)
            tasks.removeAll { $0.id == task.id }
            taskLogs[task.id] = nil
            if tasks.isEmpty && composerMode == .none && !showingSettings {
                showingTaskPanel = false
            }
            await refreshTasks(force: true)
        } catch {
            print("Failed to delete task: \(error)")
        }
    }

    func logs(for taskID: CodexTask.ID) -> [TaskEvent] {
        taskLogs[taskID] ?? []
    }

    func loadLogs(for task: CodexTask) async {
        do {
            let logs = try await service.fetchLogs(for: task.id)
            taskLogs[task.id] = logs.sorted { $0.timestamp < $1.timestamp }
        } catch {
            print("Failed to load logs: \(error)")
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
        refreshTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                let interval = self.pollInterval
                try? await Task.sleep(for: .seconds(interval))
                await self.refreshTasks()
            }
        }
    }

    private func refreshTasks(force: Bool = false) async {
        if let nextAllowedRefresh, Date() < nextAllowedRefresh {
            if force {
                pendingForcedRefresh = true
            }
            return
        }

        if isRefreshing {
            if force {
                pendingForcedRefresh = true
            }
            return
        }

        if !force,
           let lastRefreshDate,
           Date().timeIntervalSince(lastRefreshDate) < minimumRefreshSpacing {
            return
        }

        if force {
            pendingForcedRefresh = false
        }

        isRefreshing = true
        defer {
            lastRefreshDate = Date()
            isRefreshing = false
            processPendingForcedRefresh()
        }

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
            nextAllowedRefresh = nil
        } catch {
            handleRefreshError(error)
        }
    }

    private func processPendingForcedRefresh() {
        guard pendingForcedRefresh else { return }

        if let nextAllowedRefresh, Date() < nextAllowedRefresh {
            return
        }

        pendingForcedRefresh = false
        Task { [weak self] in
            await self?.refreshTasks(force: true)
        }
    }

    private func updatePollInterval(for tasks: [CodexTask]) {
        let hasActive = tasks.contains { [.queued, .running, .waitingApproval].contains($0.status) }
        pollInterval = hasActive ? activePollInterval : idlePollInterval
    }

    private func handleRefreshError(_ error: Error) {
        if let taskError = error as? TaskServiceError {
            switch taskError {
            case let .httpError(status, message) where status == 429:
                let backoff = parseRetryAfter(from: message) ?? 60
                pollInterval = max(backoff, minimumRefreshSpacing)
                nextAllowedRefresh = Date().addingTimeInterval(backoff)
                rateLimitRetryTask?.cancel()
                rateLimitRetryTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(backoff))
                    await self?.refreshTasks(force: true)
                }
                print("Hit rate limit, backing off polling to \(Int(backoff))s")
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
