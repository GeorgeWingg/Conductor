# Conductor Toolbar Plan (George)

## Goal & Constraints
- Build a macOS menu bar controller that lets us launch, monitor, and intervene in up to ~5 concurrent Codex CLI tasks during the hackathon weekend.
- Deliver something demoable by Sunday night (September 28, 2025) with a three-person team, one developer on Windows.
- Prioritize workflows that highlight Codex autonomy (task queueing, live status, approvals) while staying within local-only constraints.

## Hackathon Stack Decision
- **Supervisor backend:** Node.js/TypeScript service that wraps Codex CLI, exposes REST/WebSocket APIs, and manages task state from Codex JSONL logs.
- **macOS menu bar UI:** SwiftUI `MenuBarExtra` app for the primary demo experience; we lean native for smooth animations, system tray affordances, and rapid iteration with Xcode.
- **Cross-platform support:** Optional Tauri shell targeting Windows/Linux for view-only and approval actions; deprioritized until MVP is stable.
- **Shared contracts:** JSON over HTTP/WebSocket between UI layers and supervisor, with a small shared schema package in the repo so SwiftUI, Tauri, and CLI scripts stay in sync.

## Research Highlights
### Codex CLI capabilities
- Codex CLI is distributed via npm/Homebrew and authenticates with ChatGPT accounts; approval modes (Suggest, Auto Edit, Full Auto) gate how much autonomy the agent has, which we can mirror in our UI. [1]
- The open-source repo ships platform installers (macOS, Linux, Windows binaries) and exposes configuration through `~/.codex/config.toml`, including MCP server support. [2]
- Non-interactive commands like `codex exec --json` already produce JSONL logs per session; open issues highlight demand for easier JSON exports and resumable sessions—our wrapper can watch the session cache instead of parsing stdout only. [3][4]
- Windows usage currently depends on WSL2, and there is an open bug where WSL2 prints raw JSON instead of the formatted TUI, reinforcing that Windows teammates should work through WSL or focus on cross-platform services instead of the macOS UI. [5]

### Toolbar / UI options
- SwiftUI’s `MenuBarExtra` lets us create a persistent macOS status bar item with custom content views, menus, and window toggles—ideal for a native-feeling controller. [6]
- Tauri provides a Rust+WebView toolkit with system-tray support and tray icons across macOS, Windows, and Linux. Its architecture uses TAO/WRY for cross-platform menus, and the tray icon API exposes menu events we can bind to Codex task actions. [7][8][9][10]

## Proposed Architecture
1. **Codex Supervisor (Node/Rust process):**
   - Wraps Codex CLI invocations (`codex exec`, `codex queue`, `codex --json`) behind an IPC/HTTP layer.
   - Watches `~/.codex/sessions/YYYY/MM/DD/*.jsonl` for updates, normalizes status (queued, running, waiting approval, failed, done).
   - Persists lightweight task metadata (title, prompt, repo path, approval mode, timestamps) in SQLite or JSON for UI queries.
2. **Menu Bar UI (SwiftUI MenuBarExtra):**
   - Displays active tasks with progress badges, approval prompts, recent logs, and quick actions (pause, resume, open logs, open terminal).
   - Offers “New Task” modal supporting text, optional spec file attachment, and toggles for approval mode / sandbox options.
   - Sends commands to supervisor via HTTP/Unix domain sockets.
3. **Cross-platform Companion (Optional Tauri app):**
   - Mirrors supervisor dashboard in a WebView so Windows teammate can iterate on task list / detail views via Tauri dev server.
   - Can downscope feature set (view-only, trigger approvals) while macOS app handles tray integration.
4. **Voice Input Spike:**
   - Evaluate macOS Speech framework + local hotword (e.g., `SFSpeechRecognizer`) for dictating task specs; fallback to push-to-talk button.

## Implementation Plan
### Phase 0 – Repo bootstrap (Tonight)
- Initialize git repo, add `Conductor-plan-george.md`, baseline README, choose license.
- Script to install Codex CLI + dependencies, commit `.codex` template config documenting approval defaults.

### Phase 1 – Codex Supervisor (Saturday AM)
- Prototype Node service using `child_process.spawn` to run `codex exec --json` and stream JSON events.
- Build session watcher to tail latest JSONL logs and map to task states.
- Expose REST endpoints (`POST /tasks`, `GET /tasks`, `POST /tasks/{id}/approve`) and WebSocket for live updates.
- Add unit tests with mocked Codex output to keep progress without live API.

### Phase 2 – Menu Bar UI (Saturday PM)
- Stand up SwiftUI app with `MenuBarExtra`, `Settings`, `TaskDetailWindow` scaffolding.
- Integrate with supervisor endpoints; display list + status pill + timestamps; show diff preview by opening terminal/log file.
- Implement approval toast (notification + “Approve/Reject” buttons) wired to supervisor.

### Phase 3 – Parallel Workstreams (Sunday)
- **Mac teammate:** Polish UI, add multi-task management (priority reorder, cancel, rerun), integrate voice input if feasible.
- **Windows teammate:**
  - Build Tauri front-end hitting the supervisor API (view tasks, send approvals) OR
  - Harden supervisor (logging, config UI, CLI wrappers) inside WSL2 where Codex runs reliably.
- **Third teammate:** Implement analytics (task duration metrics), prepare demo script, and create sample repos/tasks for presentation.

### Phase 4 – Demo Polish (Sunday eve)
- Demo flow: create task from toolbar, show live progress, approve from Windows client, display completed summary.
- Package SwiftUI app (`.app`) and produce short Loom-style screen capture.

## Risk Log & Mitigations
- **Codex CLI breaking wallclock output:** Monitor release notes; pin CLI version in `package.json`/`brew bundle` and add quick smoke test before demos. [2]
- **Windows UX gaps (WSL JSON bug):** Keep Windows usage scoped to supervisor/CLI contributions, provide log parser fallback that works even with raw JSON. [5]
- **Tray menu complexity (Tauri known issues):** If we pursue Tauri companion, keep menu interactions simple and test on macOS to avoid known separator crashes; rely on pure WebView window for complex interactions. [11]
- **Time crunch:** Lock MVP scope by Saturday 6 PM; defer voice input or cloud handoff if not stable.

## Open Questions / Next Experiments
- Do we need background auth refresh for Codex Sign-in with ChatGPT, or is API key-based auth sufficient for hackathon? (Check once we confirm account tier.)
- Can we reuse Codex MCP server mode to surface task creation as a general tool within our UI instead of hand-crafted HTTP endpoints?
- Should we store task diffs locally and surface them in UI, or simply link out to `codex` auto-generated patch files?

---
[1] https://help.openai.com/en/articles/9890733-getting-started-with-codex-cli
[2] https://github.com/openai/codex
[3] https://github.com/openai/codex/issues/266
[4] https://github.com/openai/codex/issues/362
[5] https://github.com/openai/codex/issues/275
[6] https://developer.apple.com/documentation/swiftui/menubarextra
[7] https://tauri.app/v1/guides/building/app/system-tray
[8] https://tauri.app/v2/guides/features/system-tray
[9] https://github.com/tauri-apps/wry
[10] https://github.com/tauri-apps/tao
[11] https://github.com/tauri-apps/tao/issues/214
