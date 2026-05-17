# Editor

> Trim, rewrite, and reorder turns before exporting a shareable replay.

The Editor tab is where you take a raw session and shape it for an audience. It is non-destructive — the underlying JSONL is never modified.

## Layout

`EditorView` is an `HSplitView` with two panels:

```
+--------------------+-------------------------------+
| TurnBrowserPanel   | TurnEditorPanel               |
|   min 200pt        |   min 300pt                   |
|   • Toggle/turn    |   • Text editor for user text |
|   • Preview        |   • Block counter             |
|                    |   • Modified indicator        |
|                    |   • Reset                     |
+--------------------+-------------------------------+
```

An optional live preview pane can be enabled from the toolbar.

## Editing user text

Select a turn in the browser. The right panel binds a `TextEditor` to `workingTurns[idx].userText`. As you type:

- The header shows `Blocks: N`.
- The `Modified` chip lights up when the working copy differs from the original snapshot.
- A `Reset` button discards changes for the current turn (per-turn revert).
- A `Discard Changes` button at the top discards everything and reloads from the parsed file.

Assistant blocks are not editable in this view — the Editor is intentionally a user-message + inclusion tool.

## Including and excluding turns

Each row in `TurnBrowserPanel` shows a checkbox: checked means **included**, unchecked means **excluded**. Excluded turns are filtered out by `EditorViewModel.prepareTurnsForExport()` (which also re-indexes the survivors).

Toolbar bulk actions:

- **Include All** — clear `excludedTurns`.
- **Exclude All** — fill `excludedTurns` with every index.

Right-click a turn for a context menu:

- **Exclude this turn**
- **Exclude before this** — mark every prior turn as excluded.
- **Exclude after this** — mark every later turn as excluded.

For multi-select, `Cmd+Click` adds to the selection; bulk toggle applies to the highlighted rows.

## Autosave

`EditorViewModel` debounces edits at 2 s and serializes `{excludedTurns, edits}` into `UserDefaults` under `editor-state-<sessionPath>`. When you reopen the same session the changes come back. Closing the app mid-edit is safe; nothing is lost.

To go back to a clean slate use **Discard Changes** in the toolbar — it clears both the in-memory state and the `UserDefaults` snapshot.

## Block counter

The editor shows the block count per turn — useful when a long assistant reply has many `thinking` / `tool_use` blocks. The counter reflects the original parse, not your edits (you cannot delete assistant blocks here).

## Live preview

Toggle the **Preview** disclosure to attach a third pane that renders the current turn the way [Replay](replay.md) would — Markdown text, tool disclosures, diff views — using the same `TranscriptTurnView` component the rest of the app uses. The preview is read-only and updates as you type.

## Bookmarks in the Editor

`EditorViewModel.bookmarks` carries any bookmarks the session already has, and they flow through to export. To add or remove bookmarks open **View → Bookmarks…** from the menu bar. See [Replay → Bookmarks](replay.md#bookmarks).

## Export from the Editor

The Export action (Cmd+E or the toolbar `Export…` button) opens the same sheet as the rest of the app, with one difference: it passes `prepareTurnsForExport()` instead of the raw turns. The current theme, speed default, redaction setting, OG image, and labels all come through. See [Export](export.md).

## What the Editor does not do

A few things are intentionally out of scope here:

- Editing assistant text. Use [Chats](chats.md) regenerate / branch to alter assistant responses.
- Per-block redaction. Secrets are auto-redacted at export time based on a global pattern list (see [Settings → Security](settings.md#security)).
- Adding new turns. The Editor sculpts what is there; it does not synthesize history.

Related: [Replay](replay.md) · [Export](export.md) · [Settings](settings.md).
