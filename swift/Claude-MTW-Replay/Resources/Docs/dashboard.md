# Dashboard

> The Dashboard is the home tab — project header, activity heatmap, sessions table, and a sub-tab strip for Plans / CLAUDE.md / MEMORY.md / Stats.

## Layout

```
+------------------------------------------------------+
| ProjectHeaderView                                    |
|   • Project name, real path                          |
|   • "N sessions" · last activity · first activity    |
|   • Buttons: Open in Finder · Open in Terminal       |
|   • ActivityHeatmapView (GitHub-style)               |
+------------------------------------------------------+
| Picker(.segmented): Sessions | Stats | Plans | CLAUDE.md | MEMORY.md |
+------------------------------------------------------+
| Sub-tab content fills the rest                       |
+------------------------------------------------------+
```

When no project is selected the right pane shows the `SplashEmptyView` with the mascot and a prompt to pick a project from the sidebar.

## Project header

`ProjectHeaderView` renders the active project metadata. The path shown is the **real** path on disk, not Claude Code's flattened encoding. The two action buttons hand off to standard system utilities:

- **Open in Finder** uses `NSWorkspace.selectFile`.
- **Open in Terminal** runs an AppleScript that targets `Terminal.app`.

## Activity heatmap

`ActivityHeatmapView` paints a 26-week × 7-day grid (≈ six months of history) colored by the day's session count, using `appState.theme.accent` with opacity steps for intensity. Hover any cell to see a tooltip with the date and the number of sessions; click a cell to filter the sessions table to that day (heatmap interactivity from the P3.9 polish pass).

## Sessions table

`SessionTableView` is the default sub-tab. Columns:

| Column | Notes |
|---|---|
| SESSION | Star icon (favorite toggle) · short session id |
| PREVIEW | First user message, lazily enriched in the background |
| DATE | First timestamp, sortable |
| DURATION | Difference between first and last timestamp, sortable |
| TURNS | Count of user turns, sortable |
| SIZE | File size on disk, sortable |
| ACTIONS | Replay · Transcript · Edit · MD (markdown export) |
| ✓ | Compare-mode multi-select checkbox |

Click anywhere on a row (outside the action buttons) to open the session in [Replay](replay.md). Date / Duration / Turns / Size headers toggle ascending / descending on click.

### Lazy enrichment

The table renders thousands of rows at constant cost. For each row that scrolls into view, `SessionListViewModel.enrichIfNeeded(_:)` checks whether the row already has a `preview` and, if not, dispatches a `Task.detached(priority: .utility)` to `SessionMetaService.meta(for:)` which parses the JSONL just enough to compute preview, turn count, and duration. Results are cached in the `SessionMetaEntity` SwiftData table keyed by file path and invalidated when the mtime changes.

### Sorting

`SessionSortKey` exposes four sort modes (date, duration, turns, size), each with an asc/desc toggle. The current mode is remembered while the project stays selected.

### Multi-select and chaining

Toggle the checkbox at the right of each row to enter compare/chain selection. The toolbar shows two contextual buttons once you have selections:

- **Compare (2)** — opens `SessionCompareView` as a sheet. Side-by-side layout via `HSplitView`, one `TranscriptTurnView` per pane, with semantic diff highlighting (gray identical, red/green for added/removed, yellow for modified). A header summary reads "X identical, Y modified, Z added".
- **Chain (N)** — concatenates the selected sessions chronologically, re-indexes turn numbers globally, and opens an ephemeral replay/editor view. The chain is not persisted; close the tab and it is gone.

Compare mode is capped at exactly two selections (FIFO replacement).

### Favorites

The star icon on every row calls `appState.favoritesVM.toggle(...)`, which writes a `FavoriteEntity` row to SwiftData. Favorites surface in the sidebar **Favorites** section (sorted by pinned date descending) and offer a context menu with **Remove from Favorites**.

## Sub-tabs

### Stats sub-tab

Renders a compact summary of `StatsComputer.compute(turns:)`. The full Stats tab (Cmd+6) has more depth — see [Stats](stats.md).

### Plans

Lists files under `~/.claude/plans/<encoded-dir>/*.md` (with a fallback to a flat `~/.claude/plans/` layout for older installs). The list is sorted by modification time descending; selecting an item renders the file via `MarkdownTextView`. The `<encoded-dir>` is the project path with `/` replaced by `-`, matching the convention Claude Code uses.

### CLAUDE.md

Reads `<projectPath>/CLAUDE.md` (resolved via `SessionDiscovery.claudeDirToProjectPath`) and renders it through `MarkdownTextView`. If the file is missing the panel shows an empty state with a one-liner explaining what CLAUDE.md is.

### MEMORY.md

Reads `~/.claude/projects/<encoded-dir>/memory/MEMORY.md` and renders it the same way. Useful for inspecting the long-term memory captured by Claude Code during your sessions.

## Auto-refresh

A `FileWatcher` is wired to all three discovery roots and to each currently visible project directory. On a `.created` / `.deleted` / `.modified` event the affected ViewModel reloads with a 500 ms debounce. New sessions therefore appear in the table seconds after a CLI run completes — no need to hit Refresh, although the Refresh button on the sidebar still forces an immediate rescan.

Related: [Sessions table actions](export.md) · [Replay](replay.md) · [Editor](editor.md) · [Stats](stats.md).
