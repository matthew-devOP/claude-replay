# Chats

> Live, streaming conversations through the bundled Node sidecar that wraps `@anthropic-ai/claude-agent-sdk`.

The Chats tab is the most feature-dense surface in the app. It is where you **continue** a session as a real, interactive conversation — the rest of the app reads transcripts, but Chats writes them.

## Architecture in one paragraph

A Swift `ChatViewModel` owns a `ClaudeAgent` actor. The actor forks a `node` process running `Sidecar/sidecar.js`, which lazily imports `@anthropic-ai/claude-agent-sdk` and runs its `query()` async generator. Stdin/stdout speak a line-delimited JSON protocol (`{"type":"send","text":…}`, `{"type":"agent_event",event}`, etc.). Stderr is drained on a detached task so it cannot block. A `hello` handshake with `protocol="1"` is sent first; mismatched protocol versions are refused.

## Starting a chat

There are two entry points:

1. **Resume an existing session.** Pick a project, switch to Chats, and click **Resume** next to a session. The previous transcript is loaded via `TranscriptParser.parseTranscript` and seeded into the visible turns, then the sidecar is spawned with `--resume <sessionId>`.
2. **New chat.** Click the `+` in the tab strip (see [Multi-tab](#multi-tab) below) to start without resuming. The first send creates a fresh session id.

Status chips at the top of the chat reflect the lifecycle:

| Chip | Meaning |
|---|---|
| Idle | No conversation started yet |
| Connecting… | Sidecar spawning, SDK importing |
| Ready • | Connected, awaiting input |
| Streaming… | Tokens flowing |
| Error | A pill with the error message; tooltip has the full text |

## The input bar

Multi-line `TextEditor` with `Cmd+Return` to send. While streaming, **Stop** (or `Esc`) issues a graceful stop: write `{"type":"stop"}` on stdin, wait 1 s, then `terminate()` and cancel the reader task.

### Prefix chips (parity with the Claude Code TUI)

- **`@`** — opens `NSOpenPanel` and inlines the picked file as a fenced code block. Capped at 64 KB; larger files are truncated with a note.
- **`!`** — opens a sheet for a shell command. Runs `/bin/sh -c <cmd>` inside `vm.projectPath` and inlines combined stdout/stderr (capped at 16 KB).
- **`#`** — keeps the literal `#` in the draft so the SDK treats the message as a memory directive.

### Drag-and-drop attachments

Drop one or more files anywhere on the input bar. Each file becomes an attachment chip; the bar visually highlights as a drop zone. Up to five files at a time, 64 KB each.

### Attachment preview

Click a chip to preview the attachment inline:

- **Images** render via `AsyncImage`.
- **PDFs** render via `PDFKit`.
- **Code** renders in `CodeBlockView` with the monospace font and the active theme palette.

For images, the SDK accepts an `image_url` block and the chip ships the file as a base64 data URI.

### Slash commands

Type `/` and a dropdown lists every `*.md` file found in `<projectPath>/.claude/commands/` and `~/.claude/commands/`. Pick a command and the placeholder `$ARGUMENTS` (if any) is replaced by your follow-up text before sending. Useful for repeatable workflows like `/review`, `/security-review`, or any custom command.

### Mode toggle

A three-chip selector below the input bar:

- **Plan** — read-only; the agent can think and respond but not run tools that mutate.
- **Accept Edits** — tool calls are auto-approved.
- **Default** — the agent prompts for each tool call (see [Permission management](#permission-management)).

`bypassPermissions` is intentionally **not** exposed in the UI. To enable it you must pass `--permission-mode bypassPermissions` directly to the sidecar from a custom build.

### Verbose toggle

`Ctrl+R` toggles verbose mode. Flipping it respawns the sidecar with `--partial-messages`, exposing fine-grained streaming deltas useful when debugging.

## Header controls

The header above the transcript shows the session name, file path, status chip, and:

### Model picker

Drop-down listing Opus 4.7, Sonnet 4.6, Haiku 4.5, and Default. A pricing tooltip shows per-million-token cost for input, output, and cache. Switching the model respawns the agent — the SDK only reads model selection on session start.

### System prompt

Opens a sheet with a text area to override the system prompt and two checkboxes:

- **Include CLAUDE.md** — append the project-level CLAUDE.md.
- **Include MEMORY.md** — append the long-term memory file.

Saving respawns the agent with `customSystemPrompt`. The setting persists per session in SwiftData.

### Tools

Menu listing every tool the SDK exposes (`Bash`, `Read`, `Edit`, `Write`, `Glob`, `Grep`, `WebFetch`, `WebSearch`, `NotebookEdit`, `TodoWrite`, `Task`) plus any MCP tools auto-detected from running servers. Each has a toggle; `Enable All` / `Disable All` buttons sit at the top. State is persisted per `sessionPath`.

### MCP badge

A purple capsule labelled **MCP: N** appears whenever at least one MCP server is configured. Click it for the server list. Configure servers in [Settings → MCP](settings.md#mcp-servers); the sidecar receives them via `options.mcpServers`.

### Token counter

Four chips read from the SDK `result.usage` payload:

- `↑ in` — input tokens
- `↓ out` — output tokens
- `⚡ cache-read` — cache reads
- `★ cache-write` — cache writes (creations)

Tooltips show the per-million-token price for the active model.

### Cost chips

Two chips: cumulative `$X.XXXX` for the chat and `Δ $Y.YYYY` for the last turn. Both come from `result.total_cost_usd` events. The cumulative chip is always visible (P0.10), even at `$0.0000`, so the feature stays discoverable.

### Export

Header **Export** menu re-uses the [Export](export.md) pipeline with the live turns as input. HTML / Markdown / PDF.

## Permission management

When a tool call requires permission (Default mode), the SDK emits a `permission_request` event. The sidecar forwards it; the app shows a modal:

> Allow **Bash** to run `ls -la`?
> **Once** · **Always** · **Never**

Decisions persist per `(sessionId, toolName, action_signature)` in SwiftData. The `Always` cache survives app restarts; `Never` blocks the tool for the lifetime of the session.

## Streaming render

- Markdown re-renders are throttled to every ~50 ms or on `\n` so long replies do not stall the UI.
- A blinking caret `▌` appears at the end of the last assistant text block while `status == .sending`.
- The transcript autoscrolls via `withAnimation(.spring(response: 0.4, dampingFraction: 0.85))` when new content arrives.

## Persistence and Active Chats

Every applied event updates a `ChatTranscriptEntity` row (sessionPath, projectPath, turnsJSON, accountDir, lastUpdated, costUsd, model). The sidebar **Active Chats** section surfaces every chat touched in the last 7 days for one-click resume.

## Forking (branching)

Right-click any user turn and choose **Branch from here**. The app:

1. Copies the underlying JSONL to `<id>-branch-<timestamp>.jsonl` truncated at the chosen turn.
2. Opens the branch in a new chat tab with a new session id.
3. Records `parentSessionId` in the entity so the relationship survives reload.

Long-term we render a tree view of branches; for now the parent link is informational.

## Regenerate

Hover the last assistant turn and click **↻ Regenerate**. The app drops the last assistant turn, keeps the user message, stops the agent, and re-sends. Underneath this uses `--resume <sid>` so the SDK rewinds to the previous commit cleanly.

## Multi-tab

The Chats tab has its own internal tab strip with a `+` for new chats and a close affordance on each pill. Each tab has its own `ChatViewModel`; one stuck request will not block the others. Closing a tab confirms if the chat is mid-stream.

## Continue from Replay

From any session in [Replay](replay.md), the toolbar shows **Continue (live)**. Clicking it switches to Chats, opens a new tab against that session, and resumes immediately.

## Sidecar requirements

- Node 20+.
- `@anthropic-ai/claude-agent-sdk` bundled in `Sidecar/node_modules`.
- The sidecar binary path is `Bundle.main.resourceURL!/Sidecar/sidecar.js`.
- If `node` is not found in `/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin`, or the login shell's PATH, open [Settings → Sidecar](settings.md#sidecar) and locate it manually. The same goes for the `claude` binary if you want to override it.

A heartbeat watchdog kills the sidecar after 90 s of silence, then surfaces an error chip with the last log line. See [Troubleshooting](troubleshooting.md) if you hit this.

Related: [Replay](replay.md) · [Settings → MCP](settings.md#mcp-servers) · [Export](export.md) · [Keyboard shortcuts](keyboard-shortcuts.md).
