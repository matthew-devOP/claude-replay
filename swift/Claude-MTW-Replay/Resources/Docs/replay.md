# Replay

> Native, animated player for Claude Code, Cursor, and Codex CLI session JSONLs.

The Replay tab walks through a recorded session block by block. The same parser pipeline that powers the web tool is used here, so what you see locally matches what you would share via an HTML export.

## What it can play

- **Claude Code** (`type: "user" | "assistant"` line-oriented JSONL).
- **Cursor** (`role: "user" | "assistant"` with normalization to the Claude Code shape).
- **Codex CLI** (event-based with `session_meta` / `task_started` / `response_item` / `task_complete`).
- **HTML replays** imported via Cmd+Shift+I (see [Export → Import HTML](export.md#import-html-replay)).

## Splash and empty state

If no session is selected the view shows `SplashEmptyView` with the mascot and instructions. Drag-and-dropping any `.jsonl` onto the window opens it directly (also works on the dock icon).

## Keyboard shortcuts

| Key | Action |
|---|---|
| `Space` / `K` | Toggle play/pause |
| `→` / `L` | Step forward one block |
| `←` / `H` | Step back one block |
| `Shift+→` / `Shift+L` | Next turn (skip the rest of the current one) |
| `Shift+←` / `Shift+H` | Previous turn |
| `T` | Toggle thinking blocks |
| `Esc` | Pause |
| `B` | Add a bookmark at the current turn |
| `Cmd+E` | Export the current session |

See [Keyboard shortcuts](keyboard-shortcuts.md) for the full list.

## Toolbar

The `ReplayControlsView` strip across the bottom contains:

- **Progress bar** — click anywhere to seek to that turn. `BookmarkBarView` overlays bookmark dots.
- **Backward** / **Play-Pause** / **Forward** buttons.
- **Turn N/M** indicator.
- **Speed Picker** — discrete values `0.5x, 1x, 2x, 3x, 5x, 10x, 15x, 20x` (matches `ReplayViewModel.speedSteps`).
- **Toggle Thinking** — show/hide `thinking` blocks.
- **Toggle Tools** — show/hide tool calls.
- **Continue (live)** — opens the current session in [Chats](chats.md) and starts an SDK session.

## Animation engine

`ReplayViewModel.play()` is an async loop running `@MainActor` that reveals blocks one at a time with an **adaptive delay** per block:

```
delay = min(max(charCount * 0.03, 0.6), 10.0) / speed   // seconds
```

In other words, short blocks get a 0.6 s floor, long blocks are capped at 10 s, and `speed` divides through linearly. After the last block of a turn there is a fixed 0.5 s pause before starting the next turn. Unrevealed turns render with opacity `0.25` (animated with `easeInOut(0.4)`) so you can scroll ahead without losing your place. Autoscroll uses `ScrollViewReader` keyed off the current turn index.

## Tool rendering

`ToolCallView` is a `DisclosureGroup` per tool call. The header shows:

- A colored dot — red if the tool errored, blue if it succeeded.
- The tool name (`Bash`, `Read`, `Write`, `Edit`, `Grep`, `Glob`, …).
- A short preview pulled from the input: `command` for Bash, `file_path` for Read/Write/Edit, `pattern` for Grep.

Expanded views vary by tool:

- **Bash** — `CodeBlockView` with bash highlighting.
- **Edit** — `DiffView` rendering side-by-side add/delete/context.
- **Write** — `CodeBlockView` with the new file content.
- **Generic** — pretty-printed JSON.

The tool result follows in monospaced text, green on success, red on error. Long results are scrollable inside the disclosure.

## Tool grouping

Long sequences of consecutive tool calls collapse into a single summary block once the threshold (default **5**, configurable in [Settings → Display](settings.md#display)) is met. The collapsed `DisclosureGroup` summary reads `X tool calls (names…)`; expanding it shows them in order. This keeps Codex CLI runs and large agent loops readable.

## Bookmarks

`BookmarkBarView` overlays the progress bar with colored circles for each bookmark; click a circle to seek. To add a bookmark:

1. Position to the turn you want.
2. Press `B` (or use **View → Bookmarks…**).
3. Enter a label in the inline prompt.

Bookmarks persist in SwiftData per session path. The same data round-trips through HTML export — exported replays show the bar too.

**Bookmarks editor** (View → Bookmarks…) lets you rename, reorder, delete, and import/export JSON. The on-disk format is identical to the CLI `--bookmarks FILE` schema:

```json
[
  { "turn": 5, "label": "First failure" },
  { "turn": 12, "label": "Fix applied" }
]
```

## Session compare

When two rows are selected in the Dashboard sessions table, the **Compare** action opens `SessionCompareView` from inside Replay. It is an `HSplitView` with one `TranscriptTurnView` per pane plus semantic diff highlighting:

- Identical turns are gray.
- Added / removed turns are green / red.
- Modified turns (text similarity > 80 %) are yellow.

A header summary reads `X identical, Y modified, Z added`.

## Continue (live)

The toolbar's **Continue (live)** button switches to the [Chats](chats.md) tab and opens the current session id as a resumed chat. The Replay state is preserved so you can come back later.

Related: [Editor](editor.md) · [Stats](stats.md) · [Export](export.md).
