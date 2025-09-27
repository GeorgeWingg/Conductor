import Foundation

struct CodexTask: Identifiable, Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case status
        case approvalMode
        case createdAt
        case updatedAt
        case repoPath
        case currentStep
        case needsAttention
        case progress
    }

    let id: UUID
    var title: String
    var status: TaskStatus
    var approvalMode: ApprovalMode
    var createdAt: Date
    var updatedAt: Date
    var repoPath: URL
    var currentStep: String?
    var needsAttention: Bool
    var progress: Double?

    init(
        id: UUID = UUID(),
        title: String,
        status: TaskStatus,
        approvalMode: ApprovalMode,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        repoPath: URL,
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

enum TaskStatus: String, Codable, CaseIterable {
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
}

enum TaskBadgeColor: String {
    case neutral
    case active
    case attention
    case success
    case danger
}

enum ApprovalMode: String, Codable, CaseIterable {
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
}

struct TaskEvent: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case log
        case diff
        case stateChange
        case error
    }

    let id: UUID
    let taskID: UUID
    let timestamp: Date
    let kind: Kind
    let message: String

    init(
        id: UUID = UUID(),
        taskID: UUID,
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
}
