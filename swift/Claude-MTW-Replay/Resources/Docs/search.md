# Search

> Case-insensitive substring search across one project — or across every transcript on the machine.

## Opening search

Press **Cmd+F** anywhere in the app to open the global search sheet. The sheet floats over the active tab so you do not lose your place.

## Scope

The sheet has a scope picker:

- **This project** (default when a project is selected) — searches the active project's session files only.
- **Cross-project** — searches every session under Claude Code (every account), Cursor, and Codex CLI.

There is no per-source filter beyond that — the cross-project scope hits all three roots returned by `SessionDiscovery.discoverSessions(claudeAccountDir:)`.

## Matching

`SearchService.search(query:in:...)` does case-insensitive substring matching on:

- User message text (after stripping `<system-reminder>` and other system tags).
- Every assistant block's text content.

There is no regex, no fuzzy matching, no "whole word" toggle, and no AND/OR operators. Substring `contains` is the entire query language — kept that way for predictability.

By default search caps at **50 results** across up to **30 files** per project. Large projects with thousands of sessions still respond in well under a second.

## Result rows

Each `SearchResultRowView` shows:

- The project name and short session id.
- A turn-number tag (e.g. `Turn 14`).
- A role chip (`user` / `assistant`).
- A 200-char match preview with the matched substring in context.

Click a row to dismiss the sheet and open the session in [Replay](replay.md), positioned at the matched turn. (`appState.selectSession(path:)` followed by a tab switch to `.replay`.)

## Performance notes

- Searches dispatch on a `Task.detached` so the UI remains responsive.
- Repeat searches against the same project benefit from `SessionMetaEntity` caching.
- `FileWatcher` keeps the in-memory file index up to date, so newly written sessions are searchable seconds after the CLI run ends.

## Limitations

- We do not index, so search time scales linearly with the size of the matched files. For library-grade semantic search, vector embeddings are a candidate for a future release.
- Search ignores tool input/output unless that input is rendered in the assistant text. To audit raw tool data, use [Stats](stats.md) or the [Editor](editor.md).

Related: [Replay](replay.md) · [Stats](stats.md).
