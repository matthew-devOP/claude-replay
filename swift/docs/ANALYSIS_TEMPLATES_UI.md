# Claude-MTW-Replay — Templates & UI Analysis

**Source:** Analysis by templates-explorer agent
**Date:** 2026-03-28

---

## Template Files

| File | Size | Purpose |
|------|------|---------|
| `template/player.html` | ~2500 lines | Self-contained replay player |
| `template/dashboard.html` | ~97KB | Project dashboard |
| `template/editor.html` | ~63KB | 3-panel session editor |
| `template/replay.html` | ~211 lines | Replay wrapper for iframe |
| `template/lazygit.html` | ~228 lines | Terminal for lazygit |
| `template/docs.html` | ~750+ lines | Built-in documentation |
| `template/shared.css` | ~9KB | Shared design system |
| `template/player.min.html` | auto-generated | Minified player |

---

## Design System (shared.css)

### Color Palette (Tokyo Night default)
```css
--bg: #1a1b26
--bg-surface: #24253a
--bg-hover: #2f3147
--text: #c0caf5
--text-dim: #565f89
--text-bright: #e0e6ff
--accent: #bb9af7
--accent-dim: #7957a8
--green: #9ece6a
--blue: #7aa2f7
--orange: #ff9e64
--red: #f7768e
--cyan: #7dcfff
--border: #3b3d57
--tool-bg: #1e1f33
--thinking-bg: #1c1d2e
```

### Typography
- System: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif
- Mono: 'SF Mono', 'Cascadia Code', 'Fira Code', 'JetBrains Mono', 'Consolas'

### Components
- **App Header (48px):** Logo, app name, version badge, nav links, theme dropdown
- **App Footer (28px):** Left/right sections, 11px dim text
- **Theme Dropdown:** Color dot preview, dropdown menu
- **Buttons:** `.btn`, `.btn-primary`, `.btn-small`, `.btn-icon` (32x32)
- **Spinner:** 16x16, 0.8s spin animation
- **Toast:** Fixed bottom-right, slide-up/down 0.3s
- **Help Modal:** 480px centered, keyboard shortcut grid
- **Scrollbar:** 6px width, 3px border-radius
- **Stat Bars:** Horizontal bar charts

---

## Player (player.html) — The Core UI to Recreate

### HTML Structure
```
.container
  .controls (fixed bottom)
    Controls row: Prev/Play/Next, title, progress text, chapter dropdown, speed/filter/export popovers
    Progress bar: clickable fill, turn dots, bookmark dots, tooltip
  .splash — title screen with play button
  .transcript — scrollable conversation
```

### Visual Design

**Controls bar:** Max-width 960px centered, bg-surface, 34px buttons, 4px radius
**Progress bar:** 4px height (6px hover), accent fill, smooth transitions
**Splash:** Full overlay, 64px play button (accent border circle)

**Turn styling:**
- Opacity: 0.25 default → 0.35 visible → 1.0 active (0.4s transition)
- User: bg-surface, 3px accent left border, uppercase accent label
- Assistant: 3px cyan left border, uppercase cyan label
- System: italic

**Text rendering:**
- Markdown: headers, code blocks (bg, border, 6px radius), inline code, bold, italic, links, tables, lists, HR
- Collapsible long content (>10-15 lines): gradient fade, "Show more" toggle

**Tool blocks:**
- 6px radius, tool-bg background
- Header: indicator dot (8px, blue/red), tool name (cyan bold), args preview (dim), chevron
- Body: input (dim) + result (green), max-height 300px scroll
- Diff view: red `.diff-line-del`, green `.diff-line-add`
- Tool groups (5+): collapsible with count + unique names

**Thinking blocks:** 2px dim left border, collapsible, dim text

**Animations:**
- Block reveal: `blockFadeIn` 0.2s from translateY(4px) + opacity 0
- Active indicator: 2px accent left border + spinner
- Typing cursor: 7px×14px accent block, blink 1s
- Bookmark dividers: orange left border, uppercase

### JavaScript Player Engine (~1200 lines)

**Constants:**
- Speed steps: [0.5, 1, 2, 3, 5, 10, 15, 20]
- ANIMATE_MIN_DELAY: 600ms
- ANIMATE_FALLBACK_DELAY: 800ms
- ANIMATE_MAX_DELAY: 10000ms
- PEEK_OFFSET: 20px
- SHORT_TURN_DELAY_MS: 5000ms
- TURN_SCROLL_MS: 600ms

**Custom Markdown renderer:** Fenced code blocks, headers, lists (ul/ol), tables, HR, bold, italic, inline code, links

**Player state machine:**
- `currentTurn` (0 = splash), `playing`, `speed`
- `animatePausedState` for mid-turn pause
- Block-level stepping: ArrowRight/Left reveal/hide one block at a time
- `animateTurn()` uses timestamp gaps, `adaptiveWait()` reads speed live
- `smoothScrollTo()` with ease-in-out curve

**Keyboard Shortcuts:**
- Space/K: play/pause
- Right/L: step forward (block-by-block)
- Left/H: step back
- Shift+Right/L: next turn
- Shift+Left/H: previous turn
- Ctrl/Cmd+Right/L: next thinking/tool block
- T: toggle thinking
- Escape: stop

---

## Dashboard (dashboard.html)

### Layout
CSS Grid `300px 1fr`. Left sidebar: project cards (name, git branch, session count). Main panel: tabs.

### Tabs
- **Sessions:** Sortable table, hover preview popovers
- **CLAUDE.md / MEMORY.md:** Rendered markdown viewer
- **Stats:** Bar charts, tool usage
- **Plans:** Plan content
- **Git:** Branch info, commits, status

### Features
- Duration columns, favorites/pinned, breadcrumb navigation
- Transcript overlay with search and role filters

---

## Editor (editor.html)

### Layout
CSS Grid `260px 1fr 4px 1fr`. Header, toolbar, 3 panels, footer.

### Three Panels
1. **Left (260px):** Sessions tree + Options (theme, speed, toggles, labels, timing)
2. **Center:** Turn cards with checkboxes, editable textareas, block details, bookmarks
3. **Right:** Live iframe preview, resize handle

### JavaScript (~800 lines)
- Session loading, turn rendering, real-time preview (150ms debounce)
- Export (HTML/MD/PDF), reset, theme dropdown
- Keyboard: Ctrl+S export, / search, ? help
- Sidebar collapse, resize drag

---

## Test Fixtures & Coverage

### Unit Tests (9 files)
- Parser (all 3 formats), renderer, CLI, extract, secrets, themes, session resolver, concat, editor server
- Total: ~1600 lines of tests

### E2E Tests (Playwright, 2 specs)
- Player: 28 scenarios (splash, play/pause, stepping, keyboard, progress, chapters, diffs, errors)
- Editor: 21 scenarios (loading, preview, editing, blocks, bookmarks, options, export, reset)

### Fixtures
- `fixture.jsonl` (3 turns), `fixture-cursor.jsonl`, `fixture-codex.jsonl`
- `fixture-codex-patch.jsonl`, `fixture-codex-edges.jsonl`
- `fixture-paced.jsonl`, `fixture-system-tags.jsonl`
- `e2e/fixture.jsonl` (5 turns with thinking, tools, edit, write, errors)
