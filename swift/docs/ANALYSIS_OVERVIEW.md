# Claude-MTW-Replay — Project Analysis Overview

**Source:** Analysis by docs-explorer agent
**Date:** 2026-03-28

---

## What The Application Does

claude-replay converts AI coding session transcripts from **Claude Code**, **Cursor**, and **Codex CLI** into interactive, self-contained HTML replay files. It is a community tool (MIT license), not affiliated with Anthropic.

**Current version:** 0.6.0
**Repository:** `https://github.com/es617/claude-replay`

---

## Core Features

### 1. JSONL Transcript Parsing
Reads JSONL session logs from:
- Claude Code: `~/.claude/projects/<project>/<session-id>.jsonl`
- Cursor: `~/.cursor/projects/<project>/agent-transcripts/<id>/<id>.jsonl`
- Codex CLI: `~/.codex/sessions/<YYYY>/<MM>/<DD>/rollout-<uuid>.jsonl`

### 2. Self-Contained HTML Output
Generates single HTML file with zero external dependencies. Data is deflate-compressed and base64-encoded (60-70% size reduction), decompressed in-browser via `DecompressionStream`.

### 3. Interactive Player
- Play/pause with block-by-block animation
- Step forward/back through individual blocks within turns
- Progress bar with turn dots, bookmark dots, and hover tooltip
- Speed control (0.5x to 20x)
- Session timer (elapsed / total)
- Show/hide toggles for thinking blocks and tool calls
- Keyboard shortcuts (Space/K, arrows/H/L, Shift+arrows, T/Shift+T)
- Splash screen, bottom-anchored scrolling, bookmark/chapter navigation
- Export as PDF or Markdown, deep linking via `#turn=N`

### 4. 6 Built-in Color Themes
`tokyo-night` (default), `monokai`, `solarized-dark`, `github-light`, `dracula`, `bubbles`. Each defines 16 CSS custom properties. Custom themes supported via JSON file.

### 5. Secret Redaction
10 categories of secret patterns: private keys, AWS keys, Anthropic API keys, generic sk-/key- secrets, Bearer tokens, JWT, database connection strings, key=value secrets, env var secrets, long hex tokens. Custom redaction rules also supported.

### 6. Session Chaining
Up to 20 JSONL files concatenated into single replay, sorted chronologically.

### 7. Web-Based Dashboard and Editor
- **Project Dashboard** (`/`) — Sidebar with projects, tabs for Sessions/CLAUDE.md/Stats/Plans/Git
- **Session Editor** (`/editor`) — Three-panel: browser, editor, live preview
- **Replay Viewer** (`/replay`) — Embedded iframe with theme switching
- **Transcript Viewer** — Live search, match highlighting, content filters
- **LazyGit Integration** (`/lazygit`) — Browser-based terminal via WebSocket + node-pty + xterm.js
- **Docs Page** (`/docs`) — Built-in documentation
- **Favorites and Tags** — Persistent via SQLite
- **Session Stats** — Tool usage, bash commands, files read/edited, agents
- **Project Search** — Full-text across sessions (up to 50 results)
- **SSE Live Watcher** — Polls for new sessions every 10 seconds
- **Quick Actions** — Open in Finder or Terminal (macOS)
- **Git Tab** — Repo info, branches, commits, graph

### 8. Timing Modes
- `auto`: Uses real timestamps if available, falls back to paced
- `real`: Uses original timestamps
- `paced`: Synthetic timing based on content length

### 9. Tool Call Rendering
- Codex `exec_command` maps to `Bash`, `apply_patch` to `Edit`/`Write`
- Edit: unified diff (red/green), Write: code blocks
- Failed tool calls: red error indicator
- Consecutive tool calls (5+) grouped

---

## End-to-End User Flows

### CLI Flow
1. `claude-replay <session-id-or-path> -o replay.html`
2. CLI parses args → resolve session → parse JSONL → detect format → build turns
3. Apply turn filtering, timing, bookmarks
4. Render: secret redaction → JSON serialize → compress → template injection
5. Write HTML to file or stdout

### Dashboard Flow
1. `claude-replay` (no args) → HTTP server on 127.0.0.1:7331
2. Browser opens dashboard → GET /api/projects
3. User selects project → POST /api/projects/details
4. Session stats, transcript viewer, replay viewer, markdown export, editor

---

## Technology Stack

| Component | Technology |
|-----------|-----------|
| Runtime | Node.js 18+ (ES modules, .mjs) |
| Browser | Vanilla JS (no frameworks) |
| Database | better-sqlite3 (WAL mode) |
| Terminal | node-pty + ws + xterm.js |
| Build | esbuild (template minification) |
| Tests | Node built-in test runner + Playwright |
| Lint | oxlint |

### Dependencies
| Package | Purpose |
|---------|---------|
| `better-sqlite3` | SQLite for caching |
| `node-pty` | PTY for lazygit terminal |
| `ws` | WebSocket server |
| `@xterm/xterm` | Browser terminal emulator |
| `esbuild` | Template minification |
| `@playwright/test` | E2E testing |

---

## CLI Options (Complete)

| Flag | Default | Description |
|------|---------|-------------|
| `--port N` | 7331 | Editor server port |
| `--host` | 127.0.0.1 | Bind address |
| `-o, --output` | stdout | Output HTML file |
| `--turns N-M` | all | Turn range filter |
| `--exclude-turns` | none | Exclude specific turns |
| `--from/--to` | none | Time range filter |
| `--speed N` | 1.0 | Playback speed (0.1-10) |
| `--no-thinking` | false | Hide thinking blocks |
| `--no-tool-calls` | false | Hide tool calls |
| `--theme NAME` | tokyo-night | Theme name |
| `--theme-file` | none | Custom theme JSON |
| `--no-auto-redact` | false | Disable secret redaction |
| `--redact "text"` | none | Custom redaction rules |
| `--title` | auto | Page title |
| `--timing MODE` | auto | Timing mode |
| `--mark "N:Label"` | none | Bookmarks |
| `--no-minify` | false | Unminified template |
| `--no-compress` | false | Raw JSON |
| `--open` | false | Open in browser |

---

## API Endpoints (25+)

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/sessions` | List sessions + home dir + version |
| GET | `/api/themes` | List theme names |
| GET | `/api/projects` | List all projects |
| GET | `/api/favorites` | Get favorites |
| GET | `/api/tags` | Get tagged sessions |
| GET | `/api/cache-info` | Cache statistics |
| GET | `/api/events` | SSE live watcher |
| POST | `/api/browse` | Browse directory |
| POST | `/api/load` | Parse JSONL, create session |
| POST | `/api/edit` | Update turn text |
| POST | `/api/preview` | Render preview HTML |
| POST | `/api/export` | Export HTML |
| POST | `/api/reset` | Restore original |
| POST | `/api/projects/details` | Project details (paginated) |
| POST | `/api/session-stats` | Compute/cache stats |
| POST | `/api/export-md` | Export Markdown |
| POST | `/api/transcript` | Full turn data |
| POST | `/api/search` | Cross-session search |
| POST | `/api/render-replay` | Render for iframe |
| POST | `/api/favorites` | Add/remove favorite |
| POST | `/api/tags` | Set tags |
| POST | `/api/git-info` | Basic git info |
| POST | `/api/git-details` | Detailed git info |
| POST | `/api/open` | Open in Finder/Terminal |

---

## Theme CSS Variables (16)

`bg`, `bg-surface`, `bg-hover`, `text`, `text-dim`, `text-bright`, `accent`, `accent-dim`, `green`, `blue`, `orange`, `red`, `cyan`, `border`, `tool-bg`, `thinking-bg`

---

## Version History

| Version | Key Features |
|---------|-------------|
| 0.1.0 | Core player, 6 themes, parser, compression, redaction |
| 0.2.0 | Cursor support, diff view, code blocks, error indicators |
| 0.3.0 | Extract command, custom redact, OG meta tags |
| 0.4.0 | Web editor, Codex support, session chaining |
| 0.5.0 | Dashboard, transcript viewer, docs page, theme dropdown |
| 0.6.0 | SQLite cache, favorites/tags, lazygit, SSE, git integration |
