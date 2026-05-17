# Stats

> Quantitative view of a session: turn counts, block kinds, tool usage, files touched, agents spawned, durations.

The Stats tab takes the parsed turns and runs them through `StatsComputer.compute(turns:)`. All numbers are derived on demand and cached in SwiftData as `SessionStatsEntity` keyed by file path; the cache invalidates automatically when the file's mtime changes.

## Overview cards

`StatsOverviewCards` shows a 2x2 grid:

| Card | Value |
|---|---|
| Turns | Number of user turns |
| Duration | Total elapsed time between first and last timestamps |
| Errors | Count of tool calls flagged `isError` |
| Tools Used | Distinct tool names invoked |

## Tool breakdown chart

`ToolBreakdownChart` is rendered with **Swift Charts** (`import Charts`). A horizontal `BarMark` per tool, sorted by count descending, colored from `appState.theme.accent` so the chart respects whichever theme is active. Hover or click a bar to see the exact count.

## Bash commands

`BashCommandsListView` lists every command extracted from `Bash` tool calls, in order:

- Truncated command text (full text in a tooltip).
- Turn index — click to jump to that turn in Replay.
- Red error indicator when `isError == true`.

This is the fastest way to audit "what shell commands did Claude run?" across a long session.

## Files accessed

`FilesAccessedView` splits two lists side-by-side:

- **Files read** — unique `file_path` values from `Read` tool calls.
- **Files edited** — unique `file_path` values from `Edit` and `Write` tool calls.

Both are deduplicated via a `Set`. Click any path to reveal it in Finder.

## Agents

`AgentsListView` enumerates every sub-agent spawned via the `Task` tool:

- Name
- Model (e.g. `claude-sonnet-4-6`)
- Prompt (truncated at 200 chars)
- Mode (Plan / Accept Edits / Default)

Useful when debugging multi-agent runs where the top-level conversation is short but the children did all the work.

## Character counts and turn shape

Below the lists, an additional panel shows:

- **Char counts** — split by user, assistant text, and thinking blocks.
- **Avg blocks per turn**.
- **Longest turn** with a jump-to-turn link.

## Cache behavior

`SessionStatsEntity` stores the full serialized `SessionStats` as a JSON blob. Reading a previously visited session is essentially free — the parser is not invoked at all. When the underlying file's mtime changes (e.g. you continued a chat from Replay), the cache is dropped and recomputed on next view.

## Sub-tab variant

The Dashboard `Stats` sub-tab renders a compact version of the same data so you can scan multiple sessions without leaving the table. The full Stats tab (Cmd+6) is for deeper inspection.

Related: [Dashboard](dashboard.md) · [Search](search.md) · [Git](git.md).
