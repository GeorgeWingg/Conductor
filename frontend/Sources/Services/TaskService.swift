import Foundation

protocol TaskService: Sendable {
    func fetchTasks() async throws -> [CodexTask]
    func createTextTask(prompt: String) async throws -> CodexTask
    func createVoiceTask(transcript: String) async throws -> CodexTask
    func updateTask(_ task: CodexTask) async throws -> CodexTask
    func deleteTask(id: CodexTask.ID) async throws
}

struct FakeTaskService: TaskService {
    private let baseURL = URL(string: "https://example.com/api")!
    private let backend = FakeTaskBackend()

    func fetchTasks() async throws -> [CodexTask] {
        try await sendFakeRequest(path: "tasks", method: "GET", payload: [:])
        return await backend.fetch()
    }

    func createTextTask(prompt: String) async throws -> CodexTask {
        try await sendFakeRequest(
            path: "tasks",
            method: "POST",
            payload: ["type": "text", "prompt": prompt]
        )
        let newTask = CodexTask(
            title: prompt,
            status: .queued,
            approvalMode: .autoEdit,
            repoPath: URL(fileURLWithPath: "~/workspace/conductor"),
            currentStep: "Queued"
        )
        await backend.insert(newTask)
        return newTask
    }

    func createVoiceTask(transcript: String) async throws -> CodexTask {
        try await sendFakeRequest(
            path: "tasks",
            method: "POST",
            payload: ["type": "voice", "transcript": transcript]
        )
        let newTask = CodexTask(
            title: transcript,
            status: .queued,
            approvalMode: .autoEdit,
            repoPath: URL(fileURLWithPath: "~/workspace/conductor"),
            currentStep: "Queued"
        )
        await backend.insert(newTask)
        return newTask
    }

    func updateTask(_ task: CodexTask) async throws -> CodexTask {
        try await sendFakeRequest(
            path: "tasks/\(task.id.uuidString)",
            method: "PATCH",
            payload: [
                "status": task.status.rawValue,
                "needsAttention": task.needsAttention
            ]
        )
        await backend.replace(task)
        return task
    }

    func deleteTask(id: CodexTask.ID) async throws {
        try await sendFakeRequest(
            path: "tasks/\(id.uuidString)",
            method: "DELETE",
            payload: [:]
        )
        await backend.remove(id: id)
    }

    private func sendFakeRequest(path: String, method: String, payload: [String: Any]) async throws {
        var body = payload
        body["method"] = method
        body["url"] = baseURL.appending(path: path).absoluteString
        let json = try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted])
        if let string = String(data: json, encoding: .utf8) {
            print("[FakeTaskService] Dispatching request:\n\(string)")
        }
        try await Task.sleep(nanoseconds: 120_000_000)
    }
}

private actor FakeTaskBackend {
    private var tasks: [CodexTask] = []

    func fetch() -> [CodexTask] { tasks }

    func insert(_ task: CodexTask) {
        tasks.insert(task, at: 0)
    }

    func replace(_ task: CodexTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
    }

    func remove(id: CodexTask.ID) {
        tasks.removeAll { $0.id == id }
    }
}
