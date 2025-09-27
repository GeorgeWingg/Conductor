import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: TaskStore
    @State private var promptInput: String = ""

    var body: some View {
        VStack(spacing: 16) {
            ControlStripView(promptInput: $promptInput)
            Divider()
            if store.tasks.isEmpty {
                EmptyStateView()
            } else {
                TaskListView(selectedTaskID: $store.selectedTaskID)
                    .frame(maxHeight: 320)
            }
        }
        .padding(16)
        .frame(width: 360)
        .task {
            await store.loadInitial()
        }
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("No tasks yet")
                .font(.title3)
                .bold()
            Text("Use the + or mic buttons to launch a Codex task, or tweak defaults in settings.")
                .multilineTextAlignment(.center)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
