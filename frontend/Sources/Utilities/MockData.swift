import Foundation

enum MockData {
    static let sampleTasks: [CodexTask] = [
        CodexTask(
            title: "Bootstrap SwiftUI menu bar",
            status: .running,
            approvalMode: .autoEdit,
            repoPath: URL(fileURLWithPath: "~/workspace/conductor"),
            currentStep: "Scaffolding project",
            progress: 0.45
        ),
        CodexTask(
            title: "Refactor JSON parser",
            status: .waitingApproval,
            approvalMode: .suggest,
            repoPath: URL(fileURLWithPath: "~/workspace/conductor"),
            currentStep: "Awaiting confirmation",
            needsAttention: true,
            progress: 0.72
        ),
        CodexTask(
            title: "Generate release notes",
            status: .completed,
            approvalMode: .fullAuto,
            repoPath: URL(fileURLWithPath: "~/workspace/conductor"),
            currentStep: "Summaries ready",
            progress: 1.0
        )
    ]
}
