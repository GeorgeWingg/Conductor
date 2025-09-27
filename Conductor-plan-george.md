# Conductor Toolbar Plan (George)

## Goal & Constraints
- Build a macOS menu bar controller that lets us launch, monitor, and intervene in up to ~5 concurrent Codex CLI tasks within a single hacking sprint.
- Keep scope focused on macOS so we can polish the native experience without cross-platform distractions.
- Prioritize workflows that highlight Codex autonomy (task queueing, live status, approvals) while staying within local-only constraints.

## Hackathon Stack Decision
- **Single Swift codebase:** SwiftUI `MenuBarExtra` app owns both the interface and task orchestration, spawning Codex CLI via `Process` and managing status with Swift Concurrency.
- **Codex CLI bridge:** Shared Swift models parse Codex JSONL output so UI components and background services stay in sync.
- **Local data layer:** Store lightweight task metadata (prompt, mode, timestamps) in JSON so we can persist between app launches without extra services.

## Research Highlights
### Codex CLI capabilities
- Codex CLI is distributed via npm/Homebrew and authenticates with ChatGPT accounts; approval modes (Suggest, Auto Edit, Full Auto) gate how much autonomy the agent has, which we can mirror in our UI. [1]
- The open-source repo ships platform installers (macOS, Linux, Windows binaries) and exposes configuration through `~/.codex/config.toml`, including MCP server support. [2]
- Non-interactive commands like `codex exec --json` already produce JSONL logs per session; open issues highlight demand for easier JSON exports and resumable sessions—our wrapper can watch the session cache instead of parsing stdout only. [3][4]

### Toolbar / UI options
- SwiftUI’s `MenuBarExtra` lets us create a persistent macOS status bar item with custom content views, menus, and window toggles—ideal for a native-feeling controller. [5]
- Combine SwiftUI views with AppKit window management for focused task modals while keeping the core logic in Swift.

## Proposed Architecture
1. **Codex Task Manager (Swift):**
   - Launches Codex CLI commands through `Process`, streams stdout/stderr, and parses JSON events into Swift structs.
   - Watches `~/.codex/sessions/YYYY/MM/DD/*.jsonl` to recover history and update state transitions (queued, running, waiting approval, failed, done).
   - Persists lightweight task metadata (title, prompt, repo path, approval mode, timestamps) to a local JSON store for quick reloads.
2. **Menu Bar UI (SwiftUI MenuBarExtra):**
   - Displays active tasks with progress badges, approval prompts, recent logs, and quick actions (pause, resume, open log file, open repo).
   - Provides a “New Task” sheet supporting text input, optional spec file attachment, approval mode, and target repo selection.
   - Surfaced actions communicate directly with the task manager via shared state, avoiding network calls.
3. **Voice Input Spike:**
   - Evaluate macOS Speech framework + push-to-talk control for dictating task specs; keep feature flaggable if reliability lags.

## Implementation Plan
### Build Sequence
- **Step 1 – Project setup:** Confirm git repo, add baseline README, document prerequisites (Codex CLI, Xcode), and capture default Codex config.
- **Step 2 – Codex integration:** Implement Swift `TaskManager` that launches `codex exec --json`, tails session files, and normalizes task state.
- **Step 3 – Menu bar UI:** Create `MenuBarExtra` scene with active task list, detail popover, and approval controls wired to the task manager.
- **Step 4 – Demo polish:** Add notifications, voice-input experiment, sample tasks, and a short walkthrough recording.

## Risk Log & Mitigations
- **Codex CLI output changes:** Monitor release notes, pin CLI version via Homebrew/npm, and run a quick smoke task before demos. [2]
- **JSON parsing fragility:** Reference community issues asking for better JSON exports to ensure the parser tolerates partial lines and resumable sessions. [3][4]
- **Menu bar state sync:** Use SwiftUI + `ObservableObject` carefully so `MenuBarExtra` updates stay responsive.
- **Scope creep:** Keep optional features (voice, analytics) behind flags so the core task loop stays shippable.

## Open Questions / Next Experiments
- Do we need background auth refresh for Codex Sign-in with ChatGPT, or is API key-based auth sufficient for hackathon? (Check once we confirm account tier.)
- Can we reuse Codex MCP server mode to surface task creation as a general tool within our UI instead of hand-crafted HTTP endpoints?
- Should we store task diffs locally and surface them in UI, or simply link out to `codex` auto-generated patch files?

---
[1] https://help.openai.com/en/articles/9890733-getting-started-with-codex-cli
[2] https://github.com/openai/codex
[3] https://github.com/openai/codex/issues/266
[4] https://github.com/openai/codex/issues/362
[5] https://developer.apple.com/documentation/swiftui/menubarextra
