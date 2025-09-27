import SwiftUI
import AppKit

struct TaskListView: View {
    @EnvironmentObject private var store: TaskStore
    @Binding var selectedTaskID: CodexTask.ID?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(store.tasks) { task in
                    TaskRowView(task: task, isExpanded: task.id == selectedTaskID)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                toggleSelection(for: task)
                            }
                        }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func toggleSelection(for task: CodexTask) {
        if selectedTaskID == task.id {
            selectedTaskID = nil
        } else {
            selectedTaskID = task.id
        }
    }
}

private struct TaskRowView: View {
    let task: CodexTask
    let isExpanded: Bool
    @EnvironmentObject private var store: TaskStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                StatusBadge(status: task.status)
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(task.currentStep ?? task.status.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if task.needsAttention {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                }
            }

            if isExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Latest activity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(task.title) - awaiting next Codex update…")
                        .font(.callout)
                    HStack {
                        Button("Approve") {
                            Task {
                                var updated = task
                                updated.status = .running
                                updated.needsAttention = false
                                await store.update(task: updated)
                            }
                        }
                        .disabled(task.status != .waitingApproval)
                        Button("Cancel") {
                            Task {
                                var updated = task
                                updated.status = .failed
                                updated.needsAttention = false
                                await store.update(task: updated)
                            }
                        }
                        .tint(.red)
                        Spacer()
                        Button("Open Repo") {
                            NSWorkspace.shared.open(task.repoPath)
                        }
                    }
                }
                .font(.subheadline)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        )
    }
}

private struct StatusBadge: View {
    let status: TaskStatus

    var body: some View {
        Text(status.label.uppercased())
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(status.badgeColor.color)
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
}
