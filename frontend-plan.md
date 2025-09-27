# Conductor Frontend Plan (SwiftUI)

## Goal & Scope
- Deliver a polished macOS menu bar experience that surfaces Codex task control without a standalone window.
- Align visuals with the in-progress sketch set (add links/images once assets are exported).
- Minimize configuration overhead so teammates can iterate on UI while the backend wrapper matures.

## Core UX Surfaces
1. **Menu Bar Entry:** `MenuBarExtra` icon indicating aggregate state (idle, running, needs attention). Tooltip cycles the latest task title. citeturn7view0
2. **Task Overview Popover:** Primary popover listing active + recent tasks with status badges, elapsed time, and quick actions.
3. **Task Detail Sheet:** Focused view showing extended logs, diff previews (open in Terminal if diff not ready), and approve/reject controls when Codex pauses.
4. **New Task Flow:** Modal sheet that accepts prompt text, optional spec attachment, repo selector, and approval mode.
5. **Notifications:** macOS notification center banners for “task needs approval” and “task completed,” with deep links into the detail sheet.

## Data & State Model
- `CodexTask`: `id`, `title`, `status`, `approvalMode`, `createdAt`, `updatedAt`, `repoPath`, `summary`, `pendingAction` (e.g., requiresApproval).
- `TaskLogEntry`: timestamped chunks for output, diffs, and errors.
- `AppState`: Observable object that tracks task array, selected task ID, sync status with backend agent, and UI flags (showingNewTaskSheet, showingDetail).
- Data ingress via backend JSON stream (WebSocket or file watcher bridge); fallback polling if stream unavailable.

## Component Breakdown
- `TaskMenuBarIcon`: derives icon/badge from aggregate task state.
- `TaskListView`: vertical list with `ForEach` using `DisclosureGroup` for quick log previews.
- `TaskRowActions`: approve/pause/cancel buttons, disabled states derived from `task.status`.
- `NewTaskForm`: SwiftUI form validated client-side before dispatching create command.
- `TaskDetailView`: tabbed layout for Summary, Logs, Metadata; includes “Open in Terminal” shortcut.
- `NotificationManager`: wrapper around `UNUserNotificationCenter` for dispatching banners when tasks change state.

## Technical Approach
- Use SwiftUI `MenuBarExtra` scene with `@StateObject` store so UI responds to backend updates in real time. citeturn7view0
- Bridge to backend via `TaskService` protocol; initial implementation tails JSONL files and forwards events on the main actor.
- Persist recent tasks to `Application Support/Conductor/tasks.json` so popover restores quickly on relaunch.
- Apply `.focusSection()` + keyboard shortcuts for fast approval flow (⌘⏎ to approve, ⌘⌫ to cancel).
- Integrate vector assets exported from design sketches using SF Symbols or PDF assets for retina clarity.

## Build Steps
1. **Foundation:** Create SwiftUI app target, add `MenuBarExtra`, stub `TaskStore` with mocked tasks, ensure popover + sheets exist.
2. **State wiring:** Implement JSONL parser + backend bridge, replace mocks with live updates, and keep mock provider for previews.
3. **Interactions:** Hook up quick actions, keyboard shortcuts, and notifications.
4. **Polish:** Apply sketch styling (colors, spacing), add animations for task transitions, and prepare demo script.

## Handoff & Collaboration
- UI sketches: await Figma/PNG exports; annotate each surface with component IDs to keep naming consistent.
- Backend handoff: define JSON schema (`CodexTaskDTO`, `TaskEventDTO`) in shared doc so Swift decoders stay stable.
- QA: set up a “sandbox repo” with safe tasks to exercise approve/edit/cancel paths before demo.

## Open Questions
- Do we expose Codex diff previews inline or rely on opening the repo in the default editor?
- Should we add per-task color coding (e.g., success/attention) or stick to system accent?
- Are we capturing microphone permissions early for the optional voice input spike?

Add sketch references and answers as decisions land.
