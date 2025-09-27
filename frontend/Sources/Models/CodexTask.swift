import Foundation

struct CodexTask: Identifiable, Equatable, Sendable {
    typealias ID = String

    let id: ID
    var title: String
    var status: TaskStatus
    var approvalMode: ApprovalMode
    var createdAt: Date
    var updatedAt: Date
    var repoPath: URL?
    var currentStep: String?
    var needsAttention: Bool
    var progress: Double?

    init(
        id: ID = UUID().uuidString,
        title: String,
        status: TaskStatus,
        approvalMode: ApprovalMode,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        repoPath: URL? = nil,
        currentStep: String? = nil,
        needsAttention: Bool = false,
        progress: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.approvalMode = approvalMode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.repoPath = repoPath
        self.currentStep = currentStep
        self.needsAttention = needsAttention
        self.progress = progress
    }
}

enum TaskStatus: String, CaseIterable, Sendable {
    case idle
    case queued
    case running
    case waitingApproval
    case paused
    case completed
    case failed

    var label: String {
        switch self {
        case .idle: return "Idle"
        case .queued: return "Queued"
        case .running: return "Running"
        case .waitingApproval: return "Input Required"
        case .paused: return "Paused"
        case .completed: return "Done"
        case .failed: return "Failed"
        }
    }

    var badgeColor: TaskBadgeColor {
        switch self {
        case .idle, .queued: return .neutral
        case .running: return .active
        case .waitingApproval: return .attention
        case .paused: return .neutral
        case .completed: return .success
        case .failed: return .danger
        }
    }

    init(backendStatus: String) {
        let normalized = backendStatus.lowercased()

        if normalized.contains("wait") || normalized.contains("approval") {
            self = .waitingApproval
        } else if normalized.contains("queue") || normalized.contains("pending") {
            self = .queued
        } else if normalized.contains("run") || normalized.contains("progress") {
            self = .running
        } else if normalized.contains("complete") || normalized.contains("success") {
            self = .completed
        } else if normalized.contains("fail") || normalized.contains("error") || normalized.contains("cancel") {
            self = .failed
        } else if normalized.contains("pause") {
            self = .paused
        } else {
            self = .idle
        }
    }

    var isTerminal: Bool {
        switch self {
        case .completed, .failed:
            return true
        default:
            return false
        }
    }
}

enum TaskBadgeColor: String, Sendable {
    case neutral
    case active
    case attention
    case success
    case danger
}

enum ApprovalMode: String, CaseIterable, Sendable {
    case suggest
    case autoEdit
    case fullAuto

    var label: String {
        switch self {
        case .suggest: return "Suggest"
        case .autoEdit: return "Auto Edit"
        case .fullAuto: return "Full Auto"
        }
    }

    init(backendValue: String) {
        switch backendValue.lowercased() {
        case "full-auto", "full_auto": self = .fullAuto
        case "auto-edit", "auto_edit": self = .autoEdit
        default: self = .suggest
        }
    }
}

struct TaskEvent: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable {
        case log
        case diff
        case stateChange
        case error
    }

    let id: UUID
    let taskID: CodexTask.ID
    let timestamp: Date
    let kind: Kind
    let message: String

    init(
        id: UUID = UUID(),
        taskID: CodexTask.ID,
        timestamp: Date = Date(),
        kind: Kind,
        message: String
    ) {
        self.id = id
        self.taskID = taskID
        self.timestamp = timestamp
        self.kind = kind
        self.message = message
    }

    init?(dto: TaskLogDTO, taskID: CodexTask.ID) {
        guard let message = dto.message else { return nil }
        let rawKind = dto.type?.lowercased() ?? "log"
        let kind = Kind(rawValue: rawKind) ?? .log
        let timestamp = dto.timestamp ?? Date()
        self.init(taskID: taskID, timestamp: timestamp, kind: kind, message: message)
    }
}
