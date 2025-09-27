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
    @State private var isHovering = false

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
                if task.status.isTerminal {
                    Button(role: .destructive) {
                        Task { await store.delete(task: task) }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 4)
                    .opacity(isHovering ? 1 : 0.6)
                    .help("Delete task")
                }
            }

            if isExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Latest activity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(task.currentStep ?? "Awaiting Codex update…")
                        .font(.callout)
                    HStack {
                        Button("Approve") {
                            Task { await store.approve(task: task) }
                        }
                        .disabled(task.status != .waitingApproval)

                        Button("Cancel") {
                            Task { await store.cancel(task: task) }
                        }
                        .tint(.red)

                        Spacer()

                        if let repo = task.repoPath {
                            Button("Open Repo") {
                                NSWorkspace.shared.open(repo)
                            }
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
        .onHover { hovering in
            isHovering = hovering
        }
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
