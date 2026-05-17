# UI Overview

> A whirlwind tour of the eight tabs, the sidebar, the toolbar, and the global sheets.

## Window layout

The main window uses `NavigationSplitView`: a persistent left **Sidebar** and a right **Detail** pane. The detail pane is wrapped by a tab bar that switches between eight feature tabs. Two global sheets (Export and Search) and a Keyboard Shortcuts panel float above the active tab.

```
+----------------------------------------------------+
| Toolbar:  [spinner verb]  [theme] [acct] [search]  |
+--------+-------------------------------------------+
|        |  MainTabBar: Dashboard | Chats | Replay … |
| Side-  |  +-------------------------------------+  |
| bar    |  |   <Selected tab view fills here>    |  |
|        |  +-------------------------------------+  |
+--------+-------------------------------------------+
```

## The eight tabs

| # | Tab | Shortcut | Purpose |
|---|---|---|---|
| 1 | **Dashboard** | Cmd+1 | Project overview, sessions table, sub-tabs (Stats / Plans / CLAUDE.md / MEMORY.md). See [Dashboard](dashboard.md). |
| 2 | **Chats** | Cmd+2 | Live, streaming conversation through the bundled Node sidecar. See [Chats](chats.md). |
| 3 | **Replay** | Cmd+3 | Animated playback of the active session, block by block. See [Replay](replay.md). |
| 4 | **Transcript** | Cmd+4 | Static, filterable, searchable transcript view. |
| 5 | **Editor** | Cmd+5 | Edit user turns and exclude turns before export. See [Editor](editor.md). |
| 6 | **Stats** | Cmd+6 | Metrics, tool breakdown chart, bash list, files, agents. See [Stats](stats.md). |
| 7 | **Git** | Cmd+7 | Read-only git overlay for the selected project. See [Git](git.md). |
| 8 | **Docs** | Cmd+8 | This in-app documentation. |

The list above is generated truth-driven from `AppTab.allCases` so it stays in sync with the code.

## Sidebar

The sidebar is always visible. It groups projects by source (Claude Code, Cursor, Codex CLI) using disclosure sections. Header controls:

- **Search field** — substring filter on project name and path.
- **Sort menu** — by last activity (default), name, or session count.
- **Account switcher** (only visible when more than one Claude account exists). See [Accounts](accounts.md).
- **Refresh** button — rescans all three roots.

Below the project list there are two stub sections — **Favorites** and **Tags** — that surface entries you star or tag from the sessions table.

## Top toolbar

The toolbar is part of the main window (not a separate `NSToolbar`):

- **Spinner verb** in the principal placement: a cycling list of 187 playful verbs with a shimmer sweep, shown while background work runs.
- **Theme quick toggle** (sun / moon) — flips between Claude Dark and Claude Light instantly.
- **Theme menu** — pick any of the eight built-in themes or any custom theme you have loaded; see [Settings](settings.md#themes).
- **Account switcher** (when applicable).
- **Search** button — opens the global search sheet (also Cmd+F).
- **Help** (?) — opens the Keyboard Shortcuts panel.

## Menu bar status item

The app installs an `NSStatusItem` in the macOS menu bar with quick actions:

- Open last session
- Open project (recent submenu — up to 10 entries)
- Settings…
- Quit

The menu bar item lets you jump back to a recent session even when the main window is hidden.

## Global sheets

| Sheet | Trigger | Source |
|---|---|---|
| **Export** | Cmd+E or row actions | See [Export](export.md). |
| **Global Search** | Cmd+F | See [Search](search.md). |
| **Keyboard Shortcuts** | Cmd+/ or `?` | See [Keyboard shortcuts](keyboard-shortcuts.md). |
| **Bookmarks Editor** | View → Bookmarks… | Inline editor with Import/Export JSON. |

## Preferences

Open `Settings…` (Cmd+,) for a standard macOS Preferences window. Sections cover Playback defaults, Security (auto-redact), Display (tool grouping threshold, OG image), Custom Themes, Privacy & Diagnostics, MCP servers, and the Sidecar locator. See [Settings](settings.md).

## Theme picker

Themes apply instantly without reload. The picker reads `Theme.named(_:)` against the currently registered themes (eight built-ins plus any custom JSON files you have loaded). Each `Theme` value is plumbed through `appState.theme` and every view reads colors from it (`appState.theme.bg`, `.accent`, `.textDim`, etc.). The same theme is applied to HTML exports through `ThemeService.themeToCss(_:)` so a Tokyo Night replay you watched live looks identical when shared.

See also: [Settings → Custom Themes](settings.md#custom-themes).
