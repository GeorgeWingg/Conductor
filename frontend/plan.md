# Conductor Frontend Plan (SwiftUI)

## Goal & Scope
- Deliver a polished macOS menu bar experience for orchestrating Codex tasks using the SwiftUI sketch shown in the latest wireframe (3-button empty state, task list states).
- Keep the stack Swift-only so we can iterate fast while the Node backend matures separately.
- Capture UI requirements from the sketch so component work can begin before high-fidelity assets land.

## Visual Layout
1. **Menu Bar Entry:** Circular icon + badge communicates aggregate state (idle, running, attention). Tooltip rotates the most recent task title. citeturn7view0
2. **Button Row:** Three controls inspired by macOS traffic lights:
   - Left: `+` text task button → opens inline text entry field.
   - Middle: microphone button → opens waveform-styled voice capture.
   - Right: gear button → opens settings sheet with approvals defaults, log retention, and Codex path.
3. **Empty State:** When no tasks exist, show the three buttons with guidance copy (“Start a text task”, “Use voice”, “Adjust settings”).
4. **Active Task Pane:** Below the buttons, list tasks with badges (e.g., `RUN`, `PAUSED`, `ATTN`) and concise status lines (“Current step”, “Input required”). Selecting a task expands its details.
5. **Task Detail Panel:** Expanded card shows steps, live log snippets, and action buttons (Approve, Cancel, Minimize). Collapses back into list when dismissed.

## Data Model
- `CodexTask`: `id: UUID`, `title: String`, `status: TaskStatus`, `mode: ApprovalMode`, `createdAt: Date`, `updatedAt: Date`, `repoPath: URL`, `currentStep: String?`, `needsAttention: Bool`, `progress: Double?`.
- `TaskStatus` enum: `.idle`, `.queued`, `.running`, `.waitingApproval`, `.paused`, `.completed`, `.failed`.
- `TaskEvent`: `taskID`, `timestamp`, `kind` (`log`, `diff`, `stateChange`, `error`), `payload` (raw text or structured diff info).
- `VoiceDraft`: temporary struct containing transcript text, audio level meter values, recording state.
- `TaskStore`: `ObservableObject` holding `[CodexTask]`, `selectedTaskID`, `isRecordingVoice`, `isShowingSettings`, plus helper methods (`createTextTask`, `startVoiceRecording`, `approve(task:)`).
- Persistence: serialise `[CodexTask]` and recent `TaskEvent` summaries to `Application Support/Conductor/tasks.json` for restore.

## Component Breakdown
- `MenuBarScene`: Wraps `MenuBarExtra`, injects `TaskStore` and selects the correct icon/badge state.
- `ControlStripView`: renders the three buttons; dispatches actions to the store.
- `TextTaskComposer`: inline form with validation + send button.
- `VoiceTaskComposer`: waveform animation, record/stop controls, transcript preview.
- `SettingsSheet`: toggles for default approval mode, path selectors, voice permissions.
- `TaskListView`: list of `TaskRowView`; handles expand/collapse and keyboard navigation.
- `TaskRowView`: shows status badge, summary, and trailing action icons.
- `TaskDetailView`: tabbed layout (Steps, Logs, Metadata) with action buttons and open-in-Terminal shortcut.
- `NotificationManager`: wrapper around `UNUserNotificationCenter` to surface “needs approval” and completion alerts.

## Interaction Flows
- **Create Text Task:** Tap `+` → composer slides down → type prompt → hit `Return` or click send → optimistic task card appears with status `queued`.
- **Voice Task:** Tap mic → start recording (button toggles to stop) → transcription updates summary field → confirm to dispatch task.
- **Settings:** Tap gear → sheet with toggles, saved when dismissed.
- **Task Attention:** When backend marks `waitingApproval`, row highlights and NotificationManager fires a banner with “Approve” button.
- **Minimize Task:** Collapse detail view, leaving concise row.

## Technical Approach
- Use SwiftUI `MenuBarExtra` scene with `@StateObject TaskStore` so UI reacts to backend updates. citeturn7view0
- `TaskStore` consumes backend events via `AsyncSequence` from file watcher or WebSocket; for now provide mock publishers to unblock UI work.
- Represent buttons and states via SF Symbols + custom capsule backgrounds; convert sketch palette to asset catalog once defined.
- Manage keyboard shortcuts: `⌘N` (text composer focus), `⌘⇧V` (voice panel), `⌘,` (settings).
- Accessibility: provide VoiceOver labels for each button (e.g., “Start text task”).

## Build Steps
1. **Scaffold Project:** Create SwiftUI app target under `frontend/ConductorFrontend.xcodeproj`, add `MenuBarExtra`, inject mocked `TaskStore`.
2. **Stub Components:** Implement `ControlStripView`, `TaskListView`, `TaskRowView` with mock data to mirror sketch states.
3. **State Wiring:** Implement JSONL parser + backend bridge interface but keep mocked service until Node wrapper ready.
4. **Voice Prototype:** Integrate `SFSpeechRecognizer` for transcript capture; hide behind feature flag if permissions unavailable.
5. **Polish:** Apply design system, add animations (e.g., task insertion using `.transition(.move(edge: .top))`), prepare screenshot deck.

## Collaboration Notes
- Add exported PNG/JPEG sketches to `frontend/design/` once available and reference them from this plan.
- Backend teammate to provide `TaskStatusUpdate` JSON contract; add Swift `Codable` equivalents in shared file.
- Establish shared sample tasks (text + voice) for integration testing.

## Open Questions
- Do we store full logs locally or just tail the latest N lines per task?
- How do we present diff previews—inline text, popover, or open default editor?
- Should microphone + settings buttons stay visible when a task detail is expanded, or collapse into a toolbar header?

Append new decisions + assets as they land so the plan stays current.
