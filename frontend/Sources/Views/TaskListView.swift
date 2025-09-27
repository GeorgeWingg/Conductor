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
    @State private var isLoadingLogs = false
    @State private var hasLoadedLogs = false

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
                    if isLoadingLogs && store.logs(for: task.id).isEmpty {
                        ProgressView()
                            .controlSize(.small)
                    }
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: true) {
                            LazyVStack(alignment: .leading, spacing: 6) {
                                ForEach(store.logs(for: task.id)) { event in
                                    LogLineView(event: event)
                                }
                            }
                            .padding(.trailing, 4)
                        }
                        .frame(height: min(180, max(80, CGFloat(store.logs(for: task.id).count) * 20)))
                        .onChange(of: store.logs(for: task.id)) { logs in
                            if let last = logs.last {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }
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
        .onChange(of: isExpanded) { expanded in
            if expanded { loadLogsIfNeeded() }
        }
        .onAppear {
            if isExpanded { loadLogsIfNeeded() }
        }
    }

    private func loadLogsIfNeeded() {
        guard !hasLoadedLogs else { return }
        hasLoadedLogs = true
        isLoadingLogs = true
        Task {
            await store.loadLogs(for: task)
            await MainActor.run { isLoadingLogs = false }
        }
    }
}

private struct LogLineView: View {
    let event: TaskEvent

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(event.timestamp, style: .time)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(event.message)
                .font(.caption)
                .foregroundStyle(colorForKind(event.kind))
        }
        .id(event.id)
    }

    private func colorForKind(_ kind: TaskEvent.Kind) -> Color {
        switch kind {
        case .error: return .red
        case .diff: return .blue
        default: return .primary
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
