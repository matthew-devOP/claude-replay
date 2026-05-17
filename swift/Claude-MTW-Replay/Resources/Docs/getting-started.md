# Getting Started

> Welcome to Claude MTW Replay — a native macOS companion for Claude Code, Cursor, and Codex CLI sessions.

## What is Claude MTW Replay?

Claude MTW Replay is a SwiftUI-native app that discovers, parses, animates, edits, exports, and **continues live** every transcript produced by Claude Code, Cursor, or Codex CLI on your Mac. It replaces the static `claude-replay` web frontend with a desktop client that talks to a bundled Node sidecar wrapping `@anthropic-ai/claude-agent-sdk` for interactive chat.

Everything happens locally. Transcripts are scanned directly from the directories the underlying CLIs already write to. Live chat reuses your existing Claude credentials — there is no proprietary cloud backend.

## System requirements

- **macOS 14.0 or later** (`LSMinimumSystemVersion = 14.0`); built against the macOS 15 SDK.
- **Apple Silicon or Intel** — the DMG ships as a universal binary.
- **Node.js 20+** is required only for the [Chats](chats.md) tab. The sidecar uses `await import('@anthropic-ai/claude-agent-sdk')` and refuses to run on older Node releases.
- **Disk:** ~80 MB for the app, plus whatever your CLI transcripts take.
- **Xcode 16+** is only needed if you build from source.

## First run

When you launch the app the first time you land on the **Dashboard** tab. The left sidebar lists every project we could auto-discover. The right pane shows the project header (path, totals, GitHub-style activity heatmap) and a sortable table of sessions for the selected project.

If no project is selected yet, pick one from the sidebar — projects are sorted by most recent activity by default.

## How sessions are discovered

The app scans three well-known roots without ever asking for Full Disk Access:

| Source | Path pattern |
|---|---|
| Claude Code | `~/<account-dir>/projects/<encoded-project>/<id>.jsonl` |
| Cursor | `~/.cursor/projects/<id>/agent-transcripts/<id>/{transcript,<id>}.jsonl` |
| Codex CLI | `~/.codex/sessions/<YYYY>/<MM>/<DD>/*.jsonl` |

The Claude Code root defaults to `~/.claude`. If you also have `~/.claude-yahoo`, `~/.claude-outlook`, or any other `~/.claude-*` directory containing a `projects/` folder, they are auto-detected as additional **accounts** — see [Accounts](accounts.md).

A `<account-dir>` like `-Users-joe-my-project` is decoded back to `/Users/joe/my-project` using a greedy filesystem-aware reverse algorithm, so projects display with real paths even though Claude Code stores them with `/` flattened to `-`.

## Quick tour

1. Pick a project in the sidebar (Cmd+1 jumps back to Dashboard).
2. Click any row in the sessions table to open it in [Replay](replay.md). Press `Space` to play.
3. Switch to [Stats](stats.md) (Cmd+6) for tool breakdowns and bash command lists.
4. Switch to [Editor](editor.md) (Cmd+5) to exclude turns before exporting.
5. Hit Cmd+E to open the [Export](export.md) sheet — choose HTML, Markdown, or PDF.
6. To **continue** a Claude Code session as a live conversation, switch to [Chats](chats.md) (Cmd+2), pick the session, and press Resume.

## Continuing a chat live

Live chat requires the bundled Node sidecar to start. The first time you visit the Chats tab the app probes for `node` in `/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin`, and then `zsh -lc 'command -v node'` (so `asdf` / `fnm` / `volta` are picked up).

If detection fails, open Settings → Sidecar and pick the binaries manually. See [Settings](settings.md#sidecar) for the picker.

## Where to next

- New to the layout? Read [UI overview](ui-overview.md).
- Running multiple Claude accounts? See [Accounts](accounts.md).
- Want to learn every shortcut? See [Keyboard shortcuts](keyboard-shortcuts.md).
- Something not working? Start at [FAQ](faq.md) or [Troubleshooting](troubleshooting.md).
