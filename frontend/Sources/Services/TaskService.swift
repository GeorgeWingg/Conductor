import Foundation

protocol TaskService: Sendable {
    func fetchTasks() async throws -> [CodexTask]
    func createTextTask(prompt: String) async throws -> CodexTask
    func createVoiceTask(transcript: String) async throws -> CodexTask
    func updateTask(_ task: CodexTask) async throws -> CodexTask
}

struct FakeTaskService: TaskService {
    private let baseURL = URL(string: "https://example.com/api")!

    func fetchTasks() async throws -> [CodexTask] {
        try await Task.sleep(nanoseconds: 200_000_000)
        return MockData.sampleTasks
    }

    func createTextTask(prompt: String) async throws -> CodexTask {
        try await sendFakeRequest(
            path: "tasks",
            method: "POST",
            payload: ["type": "text", "prompt": prompt]
        )
        return CodexTask(
            title: prompt,
            status: .queued,
            approvalMode: .autoEdit,
            repoPath: URL(fileURLWithPath: "~/workspace/conductor"),
            currentStep: "Queued"
        )
    }

    func createVoiceTask(transcript: String) async throws -> CodexTask {
        try await sendFakeRequest(
            path: "tasks",
            method: "POST",
            payload: ["type": "voice", "transcript": transcript]
        )
        return CodexTask(
            title: transcript,
            status: .queued,
            approvalMode: .autoEdit,
            repoPath: URL(fileURLWithPath: "~/workspace/conductor"),
            currentStep: "Queued"
        )
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
        return task
    }

    private func sendFakeRequest(path: String, method: String, payload: [String: Any]) async throws {
        var body = payload
        body["method"] = method
        body["url"] = baseURL.appending(path: path).absoluteString
        let json = try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted])
        if let string = String(data: json, encoding: .utf8) {
            print("[FakeTaskService] Dispatching request:\n\(string)")
        }
        try await Task.sleep(nanoseconds: 150_000_000)
    }
}
