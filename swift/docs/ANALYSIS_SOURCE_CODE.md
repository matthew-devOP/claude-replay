# Claude-MTW-Replay — Source Code Analysis

**Source:** Analysis by src-explorer agent
**Date:** 2026-03-28

---

## Source Files Summary

| File | Lines | Purpose |
|------|-------|---------|
| `src/parser.mjs` | ~500 | JSONL parsing for 3 formats |
| `src/renderer.mjs` | ~150 | HTML template injection |
| `src/secrets.mjs` | ~80 | Secret detection/redaction |
| `src/themes.mjs` | ~120 | 6 built-in themes |
| `src/extract.mjs` | ~80 | Reverse render: extract from HTML |
| `src/resolve-session.mjs` | ~100 | Find JSONL across filesystems |
| `src/db.mjs` | ~200 | SQLite cache layer |
| `src/terminal.mjs` | ~60 | WebSocket PTY bridge |
| `src/editor-server.mjs` | ~1500 | HTTP API server (25+ endpoints) |
| `bin/claude-replay.mjs` | ~410 | CLI entry point |

---

## Key Data Models

### Turn
```
{
  index: number,
  user_text: string,
  blocks: AssistantBlock[],
  timestamp: string,
  system_events?: string[]
}
```

### AssistantBlock
```
{
  kind: "text" | "thinking" | "tool_use",
  text: string,
  tool_call: ToolCall | null,
  timestamp: string | null
}
```

### ToolCall
```
{
  tool_use_id: string,
  name: string,          // Bash, Edit, Write, Read, Grep, Glob, Agent, etc.
  input: object,
  result: string | null,
  resultTimestamp: string | null,
  is_error: boolean
}
```

### SQLite Tables
- `session_meta` — path (PK), project_dir, session_id, file_mtime, file_size, turn_count, duration, preview, user_previews (JSON), first_timestamp, last_timestamp, cached_at
- `session_stats` — path (PK), file_mtime, stats_json (JSON blob), cached_at
- `favorites` — path (PK), session_id, preview, project_dir, pinned_at
- `tags` — (path, tag) composite PK, created_at

---

## File 1: parser.mjs — JSONL Parsing

### Functions

1. **`cleanSystemTags(text)`** — Strips XML system tags: `<task-notification>`, `<user_query>`, `<system-reminder>`, `<ide_opened_file>`, etc. Converts task-notifications to compact `[bg-task: summary]` markers.

2. **`extractText(content)`** — Handles string content and array-of-blocks (Claude API format). Extracts `type === "text"` blocks, applies `cleanSystemTags`.

3. **`detectFormat(filePath)` / `detectFormatFromText(text)`** — Peeks at first JSON line: `type === "session_meta"` → codex, `type === "user"/"assistant"` → claude-code, `role === "user"/"assistant"` → cursor.

4. **`parseJsonl(text)`** — Line-by-line parsing. Normalizes Cursor entries to Claude Code shape.

5. **`collectAssistantBlocks(entries, start)`** — Scans consecutive assistant entries, deduplicates blocks using `seenKeys` set (key = `"kind:content"` or `"tool_use:id"`).

6. **`attachToolResults(blocks, entries, resultStart)`** — Matches tool results by `tool_use_id`, strips `<tool_use_error>` wrapper, sets `is_error`.

7. **`parseCodexPatch(patchStr)`** — Parses `*** Begin Patch` / `*** Add File:` / `*** Update File:` format. Lines `+` = additions, `-` = removals.

8. **`extractCodexUserText(text)`** — Strips Codex IDE context, extracts after `"## My request for Codex:"`.

9. **`parseCodexTranscript(text)`** — Event-based JSONL: `event_msg` (task_started/complete/user_message) and `response_item` (message/function_call/output). Maps `exec_command` → Bash, `apply_patch` → Write/Edit.

10. **`parseTranscript(filePath)`** — Main entry. Detects format, dispatches. For Claude Code/Cursor: groups user messages into turns, collects assistant blocks, attaches tool results. Merges orphan blocks. For Cursor: reclassifies all-but-last assistant blocks as thinking.

11. **`applyPacedTiming(turns)`** — 500ms pause before assistant, block duration: `min(max(charLength * 30, 1000), 10000)` ms.

12. **`filterTurns(turns, opts)`** — Filters by turnRange, excludeTurns set, timeFrom/timeTo.

---

## File 2: renderer.mjs — HTML Generation

### Functions

1. **`escapeHtml(str)`** — Escapes `&`, `<`, `>`, `"`, `'`
2. **`escapeJsonForScript(json)`** — Escapes for JS string: backslashes, quotes, newlines, `</`, `<!--`
3. **`compressForEmbed(json)`** — deflateSync + base64
4. **`buildRedactor(rules)`** — Returns function applying search/replace rules
5. **`transformStrings(obj, fn)`** — Recursive string transform on object trees
6. **`turnsToJsonData(turns, opts)`** — Maps turns with redaction applied
7. **`render(turns, opts)`** — Main: reads template, replaces 12 placeholders: `/*THEME_CSS*/`, `/*THEME_BG*/`, `/*INITIAL_SPEED*/`, `/*CHECKED_THINKING*/`, `/*CHECKED_TOOLS*/`, `/*PAGE_TITLE*/`, `/*PAGE_DESCRIPTION*/`, `/*OG_IMAGE*/`, `/*USER_LABEL*/`, `/*ASSISTANT_LABEL*/`, `/*BOOKMARKS_DATA*/`, `/*TURNS_DATA*/`

---

## File 3: secrets.mjs — Secret Redaction

### 11 Patterns
1. `private_key` — PEM private keys (multi-line)
2. `aws_key` — `AKIA` + 16 chars
3. `sk_ant_key` — `sk-ant-` + 20+ chars
4. `sk_key` — `sk-` + 20+ chars
5. `key_prefix` — `key-` + 20+ chars
6. `bearer` — `Bearer` + 20+ chars
7. `jwt` — `eyJ...eyJ...` pattern
8. `connection_string` — mongodb/postgres/mysql/redis/amqp/mssql URLs
9. `key_value` — `api_key=`, `secret_key=`, `auth_token=` etc.
10. `env_var` — `PASSWORD=`, `TOKEN=`, `SECRET=` etc.
11. `hex_token` — 40+ hex chars, word-bounded

### Functions
- `redactSecrets(text)` — Apply all patterns, replace with `[REDACTED]`
- `redactObject(obj)` — Recursive walk, apply to all strings

---

## File 4: themes.mjs

### 6 Built-in Themes
- `tokyo-night` (default dark), `monokai`, `solarized-dark`, `github-light`, `dracula`, `bubbles`
- Each has 16 CSS vars + optional `extraCss`

### Functions
- `getTheme(name)`, `loadThemeFile(path)`, `themeToCss(theme)`, `listThemes()`, `getAllThemes()`

---

## File 5: extract.mjs — Reverse Render

### Functions
- `decodeBlob(raw)` — Handles raw JSON (unescape) or compressed (base64 → inflate → parse)
- `findBlobs(html)` — Regex finds `await decode("...")` calls
- `extractData(html)` — Returns `{ turns, bookmarks }`

---

## File 6: resolve-session.mjs

### `resolveSessionId(sessionId, opts)`
Searches three locations:
- Claude Code: `~/.claude/projects/<project>/<id>.jsonl`
- Cursor: `~/.cursor/projects/<project>/agent-transcripts/<id>/transcript.jsonl`
- Codex CLI: `~/.codex/sessions/<YYYY>/<MM>/<DD>/rollout-*-<uuid>.jsonl`

---

## File 7: db.mjs — SQLite Cache

### Functions
- `getDb()` — Lazy singleton, WAL mode
- `getCachedMeta/setCachedMeta` — Session metadata with mtime invalidation
- `getCachedStats/setCachedStats` — Stats JSON with mtime invalidation
- `getFavorites/addFavorite/removeFavorite/isFavorite`
- `getTagsForSession/getAllTaggedSessions/addTag/removeTag/setTags`
- `getCacheInfo` — DB statistics

---

## File 8: terminal.mjs — WebSocket PTY

### `attachTerminalWs(httpServer)`
- node-pty spawns lazygit or shell
- WebSocket streams I/O bidirectionally
- JSON resize messages: `{ type: "resize", cols, rows }`

---

## File 9: editor-server.mjs — HTTP API (~1500 lines)

### Key Helpers
- `readBody(req)` — JSON body with 10MB limit
- `assertUnderHome(path)` — Security: path must be under $HOME
- `discoverSessions()` — Scan all 3 directories
- `discoverProjects()` — Build project list with metadata
- `claudeDirToProjectPath(dirName)` — Decode encoded dir names via filesystem probing
- `getProjectDetails(source, dirName)` — CLAUDE.md, MEMORY.md, sessions
- `computeSessionStats(turns)` — Counts, tool breakdown, bash commands, files, agents, plans
- `turnsToMarkdown(turns, title)` — Markdown export with diff formatting
- `getGitInfo/getGitDetails` — Git branch, commits, graph via execFile

### Session State
- In-memory `sessions` Map: `sessionId → { originalTurns, workingTurns, sourcePath, format }`
- `prepareTurns(session, options)` — Clone, exclude, re-index, apply timing
- `remapBookmarks(bookmarks, turns, excludedSet)` — Remap indices after exclusions

---

## File 10: bin/claude-replay.mjs — CLI

### Two Modes
1. **No args**: Launch web editor via `startEditor(port, { host })`
2. **With files**: Generate HTML replay
   - Resolve session IDs, parse JSONL, concat up to 20 sessions
   - Apply filters, timing, bookmarks, redaction
   - Render HTML, write to file or stdout

### Subcommands
- `extract <file>` — Extract data from generated HTML
