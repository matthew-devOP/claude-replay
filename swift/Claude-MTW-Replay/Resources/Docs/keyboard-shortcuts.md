# Keyboard shortcuts

> Every shortcut, in one place. The Help panel (Cmd+/) reads from this same list.

The shortcut table is generated truth-driven from `AppTab.allCases`, so the navigation block stays accurate even after we add a ninth tab.

## Navigation

| Shortcut | Action |
|---|---|
| `Cmd+1` | Dashboard |
| `Cmd+2` | Chats |
| `Cmd+3` | Replay |
| `Cmd+4` | Transcript |
| `Cmd+5` | Editor |
| `Cmd+6` | Stats |
| `Cmd+7` | Git |
| `Cmd+8` | Docs |

## Application

| Shortcut | Action |
|---|---|
| `Cmd+F` | Open global search |
| `Cmd+E` | Open export sheet for the current session |
| `Cmd+Shift+I` | Import HTML replay |
| `Cmd+,` | Open Settings (standard macOS) |
| `Cmd+/` or `?` | Open this Keyboard Shortcuts panel |
| `Cmd+W` | Close the active window |
| `Cmd+Q` | Quit |

## Replay

| Shortcut | Action |
|---|---|
| `Space` / `K` | Toggle play/pause |
| `→` / `L` | Step forward one block |
| `←` / `H` | Step back one block |
| `Shift+→` / `Shift+L` | Next turn |
| `Shift+←` / `Shift+H` | Previous turn |
| `T` | Toggle thinking blocks |
| `Esc` | Pause |
| `B` | Add a bookmark at the current turn |

## Chats

| Shortcut | Action |
|---|---|
| `Cmd+Return` | Send the current draft |
| `Esc` | Stop the in-flight response (graceful stop, then terminate) |
| `Ctrl+R` | Toggle verbose mode (respawns sidecar with `--partial-messages`) |
| `Cmd+T` | Open a new chat tab |
| `Cmd+Shift+W` | Close the current chat tab |
| `@` (prefix) | Open file picker → inline file content |
| `!` (prefix) | Run shell command → inline output |
| `#` (prefix) | Memory directive |
| `/` (prefix) | Slash commands autocomplete |

## Sidebar and tables

| Shortcut | Action |
|---|---|
| `↑` / `↓` | Move selection in the active list |
| `Enter` | Open the selected project / session |
| `Cmd+R` | Refresh discovery |
| `Cmd+Click` | Add/remove from selection (Compare mode, Editor multi-select) |

## Editor

| Shortcut | Action |
|---|---|
| `Cmd+S` | Save autosave state immediately (also runs every 2 s) |
| `Cmd+Z` / `Cmd+Shift+Z` | Standard undo / redo inside text editors |

Related: [UI overview](ui-overview.md) · [Replay](replay.md) · [Chats](chats.md).
