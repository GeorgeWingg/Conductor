import Foundation

protocol TaskService: Sendable {
    func fetchTasks() async throws -> [CodexTask]
    func createTextTask(prompt: String, approvalMode: ApprovalMode) async throws -> CodexTask
    func createVoiceTask(transcript: String, approvalMode: ApprovalMode) async throws -> CodexTask
    func approveTask(id: CodexTask.ID) async throws -> CodexTask
    func cancelTask(id: CodexTask.ID) async throws
    func deleteTask(id: CodexTask.ID) async throws
    func fetchLogs(for id: CodexTask.ID) async throws -> [TaskEvent]
}

struct BackendConfiguration {
    let baseURL: URL
    let workingDirectory: String?

    static let `default`: BackendConfiguration = {
        let processEnv = ProcessInfo.processInfo.environment
        let apiURL = processEnv["CONDUCTOR_API_URL"].flatMap(URL.init(string:)) ?? URL(string: "http://localhost:3001")!
        let workingDir = processEnv["CONDUCTOR_WORKDIR"]
        return BackendConfiguration(baseURL: apiURL, workingDirectory: workingDir)
    }()
}

struct BackendTaskService: TaskService {
    private let configuration: BackendConfiguration
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(configuration: BackendConfiguration = .default, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func fetchTasks() async throws -> [CodexTask] {
        let response: APIResponse<[TaskDTO]> = try await request(path: "/api/tasks", method: "GET")
        let tasks = response.data ?? []
        return tasks.compactMap { CodexTask(dto: $0) }
    }

    func createTextTask(prompt: String, approvalMode: ApprovalMode) async throws -> CodexTask {
        try await createTask(prompt: prompt, approvalMode: approvalMode)
    }

    func createVoiceTask(transcript: String, approvalMode: ApprovalMode) async throws -> CodexTask {
        try await createTask(prompt: transcript, approvalMode: approvalMode)
    }

    func approveTask(id: CodexTask.ID) async throws -> CodexTask {
        let _ : APIResponse<TaskDTO> = try await request(
            path: "/api/tasks/\(id)/approve",
            method: "POST",
            body: ["approved": true]
        )
        return try await fetchTask(id: id)
    }

    func cancelTask(id: CodexTask.ID) async throws {
        try await deleteTask(id: id)
    }

    func deleteTask(id: CodexTask.ID) async throws {
        let _: APIResponse<EmptyResponse> = try await request(path: "/api/tasks/\(id)", method: "DELETE")
    }

    func fetchLogs(for id: CodexTask.ID) async throws -> [TaskEvent] {
        let response: APIResponse<[TaskLogDTO]> = try await request(path: "/api/tasks/\(id)/logs", method: "GET")
        let logs = response.data ?? []
        return logs.compactMap { TaskEvent(dto: $0, taskID: id) }
    }

    // MARK: - Private helpers

    private func createTask(prompt: String, approvalMode: ApprovalMode) async throws -> CodexTask {
        let payload = TaskCreatePayload(
            prompt: prompt,
            approvalMode: approvalMode.backendValue,
            workingDir: configuration.workingDirectory
        )
        let response: APIResponse<TaskIdentifierResponse> = try await request(
            path: "/api/tasks",
            method: "POST",
            body: payload
        )

        guard let taskId = response.data?.taskId else {
            throw TaskServiceError.missingData("taskId")
        }

        return try await fetchTask(id: taskId)
    }

    private func fetchTask(id: CodexTask.ID) async throws -> CodexTask {
        let response: APIResponse<TaskDTO> = try await request(path: "/api/tasks/\(id)", method: "GET")

        guard let dto = response.data else {
            throw TaskServiceError.missingData("task")
        }

        guard let task = CodexTask(dto: dto) else {
            throw TaskServiceError.unableToDecodeTask
        }
        return task
    }

    private func request<T: Decodable>(path: String, method: String) async throws -> T {
        try await request(path: path, method: method, bodyData: nil)
    }

    private func request<T: Decodable, Body: Encodable>(path: String, method: String, body: Body) async throws -> T {
        let data = try encoder.encode(body)
        return try await request(path: path, method: method, bodyData: data)
    }

    private func request<T: Decodable>(path: String, method: String, bodyData: Data?) async throws -> T {
        let trimmedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let url = configuration.baseURL.appendingPathComponent(trimmedPath)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TaskServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw TaskServiceError.httpError(status: httpResponse.statusCode, message: message)
        }

        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - DTOs & Helpers

private struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: String?
    let message: String?
}

private struct TaskIdentifierResponse: Decodable {
    let taskId: String
}

private struct TaskCreatePayload: Encodable {
    let prompt: String
    let approvalMode: String
    let workingDir: String?
}

private struct TaskDTO: Decodable {
    let id: String
    let prompt: String
    let workingDir: String?
    let approvalMode: String?
    let status: String
    let startTime: Date?
    let endTime: Date?
    let updatedAt: Date?
    let createdAt: Date?
    let logs: [TaskLogDTO]?
}

struct TaskLogDTO: Decodable {
    let timestamp: Date?
    let type: String?
    let message: String?
}

private struct EmptyResponse: Decodable {}

enum TaskServiceError: LocalizedError {
    case missingData(String)
    case invalidResponse
    case httpError(status: Int, message: String?)
    case unableToDecodeTask

    var errorDescription: String? {
        switch self {
        case .missingData(let key): return "Missing expected data: \(key)"
        case .invalidResponse: return "Invalid response from server"
        case .httpError(let status, let message):
            return "HTTP error (\(status)): \(message ?? "No server message")"
        case .unableToDecodeTask: return "Unable to decode task payload"
        }
    }
}

private extension ApprovalMode {
    var backendValue: String {
        switch self {
        case .suggest: return "suggest"
        case .autoEdit: return "auto-edit"
        case .fullAuto: return "full-auto"
        }
    }
}

private extension CodexTask {
    init?(dto: TaskDTO) {
        let status = TaskStatus(backendStatus: dto.status)
        let approval = ApprovalMode(backendValue: dto.approvalMode ?? "suggest")
        let created = dto.createdAt ?? dto.startTime ?? Date()
        let updated = dto.updatedAt ?? dto.endTime ?? Date()

        let latestLog = dto.logs?.last?.message
        let needsAttention = status == .waitingApproval

        var repoURL: URL? = nil
        if let dir = dto.workingDir {
            repoURL = URL(fileURLWithPath: dir)
        }

        self.init(
            id: dto.id,
            title: dto.prompt,
            status: status,
            approvalMode: approval,
            createdAt: created,
            updatedAt: updated,
            repoPath: repoURL,
            currentStep: latestLog,
            needsAttention: needsAttention,
            progress: nil
        )
    }
}
