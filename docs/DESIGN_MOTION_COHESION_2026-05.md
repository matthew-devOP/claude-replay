# Design Audit — Animations / Motion & Overall Design Cohesion

App: Claude-MTW-Replay (SwiftUI, macOS 15 target, builds Xcode 26.3), v1.0.0
Workstream: Animations/Motion, Spacing & Radii cohesion, Typography, HIG, overall cohesion
Date: 2026-05-29 · Mode: read-only

---

## Executive verdict

The app is **functionally rich but visually under-coordinated**. Motion is sparse, ad-hoc, and inconsistent: there are only ~6 real animation sites across 80+ view files, every one with a *different* duration/easing, and the most motion-worthy moments (tab switches, chat turn insertion, sheets) have **no** transition at all. The new `DesignTokens` enum exists but is adopted at only **~21%** of corner-radius sites — the majority of cards/chips/buttons still hard-code `6`/`8`/`12` inline, and two components use the deprecated `.cornerRadius(N)` modifier. Typography is mostly semantic (good) but mixed with several pixel-literal `.system(size:)` usages, and per-tab headers are treated inconsistently (`.title` vs `.title2` vs `.headline` vs nothing). Liquid Glass is funneled cleanly through `appGlass`, but glass is applied to only 6 surfaces and **no** `glassEffectID` / coordinated morph is used anywhere. Net: it reads as **an assemblage of separately-built tabs**, not one designed product.

---

## 1. Animation / Motion inventory

Complete inventory of motion across `Views/**`:

| # | Site | What | Easing / duration |
|---|------|------|-------------------|
| 1 | `Views/Replay/ReplayView.swift:144` | Turn dim/reveal on `currentTurnIndex` | `.easeInOut(0.4)` |
| 2 | `Views/Replay/ReplayView.swift:149` | Scroll-to on turn change | `withAnimation` (**default**, unspecified) |
| 3 | `Views/Chats/ChatView.swift:258` | Autoscroll on new turn | `.spring(response:0.4, damping:0.85)` |
| 4 | `Views/Chats/ChatView.swift:264` | Autoscroll to composing indicator | `.spring(response:0.4, damping:0.85)` |
| 5 | `Views/Chats/ChatView.swift:304` | Regenerate hover button fade | `.easeInOut(0.15)` |
| 6 | `Views/Chats/ChatView.swift:353` | CaretBlink streaming pulse | `.easeInOut(0.6).repeatForever` |
| 7 | `Views/Shared/ToastView.swift:34,40,43` | Toast in/out move+opacity | `.easeInOut` (**default duration**) |
| 8 | `Views/Dashboard/ActivityHeatmapView.swift:61` | `.transition(.opacity)` on cells | (driven by ambient `.animation`?) |
| 9 | `Views/Shared/SpinnerVerbView.swift` | Shimmer + star pulse | `TimelineView(.animation)` hand-rolled |

Spinners (`ProgressView`): ChatView:183/194/238, ChatSessionListView:29, ChatsView:139, DashboardView:23, GitView:13, StatsView:16, SearchView:11, ExportProgressView:3, SessionTableView:127.

### Consistency findings (P1)

- **Every animated site uses a different timing curve.** Durations seen: `0.15`, `0.4`, `0.6`, two unspecified `withAnimation`/`.easeInOut` defaults (~0.35), plus springs. There is no shared `Animation` constant analogous to `DesignTokens`. This is a grab-bag, not a system. **(P1)**
- **Tab switching has zero motion** — `Views/ContentView.swift:16-27` is a bare `switch appState.currentTab` with no `.transition`/`.animation`; same for the chat tab strip `Views/Chats/ChatTabContainerView.swift:152-192`. Tabs hard-cut. Web parity (and HIG) would favor a subtle crossfade. **(P1)**
- **Chat turn insertion is not animated.** `Views/Chats/ChatView.swift:210-235` — `LazyVStack`/`ForEach(vm.turns)` has `.id` but no `.transition`; new streaming turns pop in instantly while the scroll springs. The append (the single most-watched motion in the app) is janky. **(P1)**
- **The active-tab highlight does not animate** — `Views/Shared/MainTabBarView.swift:44-47` and `ChatTabContainerView.swift:140-145` swap the accent-tint background with no `.animation(value: isActive)`, so selection snaps. **(P2)**
- **Toast uses default-duration `.easeInOut`** twice nested (`ToastView.swift:40` and `:43`) — redundant and slower than the 0.15 used elsewhere. **(P3)**
- **Replay scroll-to (`ReplayView.swift:149`) uses bare `withAnimation`** while the analogous chat scroll uses a tuned spring — same gesture, two behaviors. **(P2)**
- **Hover affordances are inconsistent.** Only 3 files use `onHover` (`ChatView`, `SessionRowView`, `ActivityHeatmapView`). The regenerate button fades (`ChatView:303`), but `SessionRowView` action buttons and tab-strip close buttons appear with no hover reveal/transition. No unified hover convention. **(P2)**

### Liquid Glass / macOS 26 coordination (P2)

- Glass is funneled cleanly through `appGlass` (`Extensions/GlassStyle.swift`), applied at only **6 surfaces**: ChatView regenerate (`:297`), SlashCommandPicker (`:54`), ActivityHeatmap (`:58`), DocsView (`:43`), ReplayControls (`:39`), TranscriptSearchBar (`:15`).
- **No `glassEffectID` and no real `GlassEffectContainer` usage** appear in any view (the `glassGroup` helper exists but is never called). On macOS 26, adjacent glass controls that appear/disappear (e.g. the regenerate button materializing, the replay controls cluster, search bar) should share a `GlassEffectContainer` + `glassEffectID` so they morph/merge rather than fade independently. This coordinated-morph opportunity is entirely unrealized. **(P2)**

---

## 2. Spacing & Radii cohesion

### Token-adoption stats

Corner-radius sites total = **29** (24 `RoundedRectangle(cornerRadius:)` + 4 `.cornerRadius(N)` + 1 inferred). Using `DesignTokens`: **6**.

> **DesignTokens corner-radius adoption ≈ 21%** (6 / 29). The other **~79% are raw literals.**

Padding/spacing: **zero** token usage — `DesignTokens` has no spacing/padding members, so all ~130 padding sites and ~145 stack-spacing sites are magic numbers. Most common: `padding(8)` ×15, `padding(.vertical,4)` ×13, `padding(.horizontal,8)` ×12, `padding(.horizontal,12)` ×11, `spacing:8` ×25, `spacing:4` ×20, `spacing:12` ×19, `spacing:6` ×17.

### Violations table (radii literals that should be tokens)

| File:line | Literal | Maps to | Component class |
|-----------|---------|---------|-----------------|
| `Chats/ChatInputBarView.swift:57,60,283` | `8` | `cornerMedium` | input field |
| `Chats/ChatTabContainerView.swift:141` | `6` | `cornerSmall` | tab chip |
| `Chats/PermissionAlertView.swift:32` | `6` | `cornerSmall` | code block |
| `Chats/SystemPromptSheet.swift:40` | `4` | (no token) | text area |
| `Replay/ReplayTurnView.swift:29` | `8` | `cornerMedium` | turn card |
| `Replay/ReplayTurnView.swift:85` | `6` | `cornerSmall` | sub-card |
| `Replay/ToolCallView.swift:29` | `6` | `cornerSmall` | tool card |
| `Shared/CodeBlockView.swift:24,25` | `6` | `cornerSmall` | code block |
| `Shared/DiffView.swift:38` | `6` | `cornerSmall` | diff block |
| `Shared/MainTabBarView.swift:45` | `6` | `cornerSmall` | tab chip |
| `Shared/ToastView.swift:14` | `8` | `cornerMedium` | toast |
| `Stats/AgentsListView.swift:16,34` | `6` | `cornerSmall` | card |
| `Stats/StatsOverviewCards.swift:18` | `8` | `cornerMedium` | stat card |
| `Transcript/TranscriptTurnView.swift:16` | `8` | `cornerMedium` | turn card |
| `Dashboard/ActivityHeatmapView.swift:81,106` | `.cornerRadius(2)` | (no token) | heatmap cell |
| `Dashboard/SessionCompareView.swift:159,205` | `.cornerRadius(6)` | `cornerSmall` | diff row |
| `SystemPromptSheet.swift:40` | `4` | (no token) | — |

### Inconsistency findings (P2)

- **Same component class, different radii.** "Cards" (a themed surface holding a turn/stat) appear at radius **8** (`ReplayTurnView:29`, `TranscriptTurnView:16`, `StatsOverviewCards:18`) AND radius **6** (`AgentsListView:16/34`, `ReplayTurnView:85`). No rule distinguishes them. **(P2)**
- **Tab chips disagree internally:** both `MainTabBarView:45` and `ChatTabContainerView:141` use `6` raw — at least consistent with each other, but neither uses the token. **(P2)**
- **Two deprecated `.cornerRadius(N)` modifier calls** (`SessionCompareView:159,205`, `ActivityHeatmap:81,106`) vs the modern `in: RoundedRectangle(... style:.continuous)` form used elsewhere — and none of the literal `RoundedRectangle` sites pass `style: .continuous`, while `appGlass` always does. So glass surfaces are squircle-continuous and non-glass cards are circular-arc; subtly mismatched corners. **(P2)**
- **`DesignTokens` covers radii only.** With ~275 padding/spacing magic numbers and no `spacing*`/`padding*` tokens, the token system is structurally incomplete. Recommend extending it (e.g. `spaceXS=4, spaceS=8, spaceM=12, spaceL=16, spaceXL=20`). **(P2)**

---

## 3. Typography

- **Mostly semantic — good.** Distribution: `.caption` ×90, `.caption2` ×29, `.headline` ×20, `.title2` ×7, `.body` ×7, `.title` ×1. Heavy reliance on semantic styles is correct and Dynamic-Type-friendly.
- **Pixel-literal escapes (P3):** `.system(size:)` with raw points at `SessionRowView:41,45` (9pt), `SessionTableView:188` (10pt), `SessionTableView:216` (7pt), `BookmarksEditorView:61` (32pt), `MainTabBarView:37,39` (12/13pt), `SpinnerVerbView:63,69,73` (13/14pt), `SplashEmptyView:31` (80pt), `EmptyStateView:6` (variable). The 7pt and 9pt text in the dashboard table won't scale and is below comfortable minimums. **(P3)**
- **Inconsistent per-tab title treatment (P2):** section/page headers use three different styles with no rule: Dashboard project header is `.title` (`ProjectHeaderView:24`), Replay/Stats/Export use `.title2` (`ReplayControlsView:29`, `EmptyStateView:7`, `ExportSheet:17`), while Git/Stats *section* headers and most sheets use `.headline` (`GitView`'s `CommitLogView:7`, `StatsView`'s `AgentsListView:7`, etc.). Some tabs (Stats, Git, Transcript) have **no page title at all** — they jump straight into content — while Dashboard and Chats have prominent ones. **(P2)**
- Monospaced is applied consistently via `.system(.body/.caption, design: .monospaced)` for code/paths — that pattern is coherent.

---

## 4. HIG / native feel

Strong points:
- `NavigationSplitView` used for the shell (`ContentView:8`) and Docs (`DocsView:7`). Idiomatic.
- Real `.toolbar` with `.principal` and `.primaryAction` placements (`ContentView:29-50`).
- `.controlSize(.small/.large)` used in ~14 places; `@FocusState`/`.focusable()` in Replay, Chat input, Sidebar, SessionTable; 22 `keyboardShortcut` sites; sheets via `.sheet(item:)`/`.sheet(isPresented:)`. All good native muscle.
- `.listStyle(.sidebar)` and `.inset` used appropriately.

Issues:
- **The `MainTabBarView` is a hand-rolled tab strip**, not a `TabView`/segmented control or native toolbar picker (`Views/Shared/MainTabBarView.swift`). It re-implements selection highlight, accessibility, and keyboard hints manually. This is the single biggest non-native element — it fights the platform and is why tab switches can't get free crossfade transitions. **(P2)**
- **Chat tabs are a second, *different* hand-rolled tab strip** (`ChatTabContainerView`) with its own chip styling — two bespoke tab systems that look different from each other. **(P2)**
- **Toast uses `DispatchQueue.main.asyncAfter`** (`ToastView.swift:36`) instead of a structured `Task`/`.task`; works but is the old idiom. **(P3)**
- Tiny tap targets: the 7pt/9pt dashboard cells and `.font(.caption2)` close buttons fall below the 44/28pt comfortable target guidance. **(P3)**
- Several `.buttonStyle(.borderless)` vs `.plain` vs `.bordered` choices look situational rather than systematic (e.g. ChatView header mixes `.borderless`, `.plain`, and bare default buttons in one row, `ChatView:91/125/128`). **(P3)**

---

## 5. Overall cohesion verdict

**It feels like an assemblage of separately-built tabs, not one designed product.** Evidence:

- Two different bespoke tab strips (main nav + chat tabs) that don't match each other and neither matches a native control.
- Cards of the same semantic class render at radius 6 in some tabs and 8 in others; glass corners are continuous-squircle while literal cards are circular-arc.
- Page-title treatment varies tab-to-tab (`.title` / `.title2` / `.headline` / none).
- Motion is present in Replay and Chats with three different timing systems and absent everywhere else (Dashboard, Stats, Git, Editor, Docs have essentially no motion).
- The `DesignTokens` enum is a good start but is radii-only and adopted at ~21%, so it isn't yet enforcing cohesion.

The bones are native and solid (NavigationSplitView, toolbars, focus, shortcuts, a clean glass funnel). What's missing is a **design-system layer**: a shared motion vocabulary, full token adoption (radii + spacing), one tab component, and a per-tab header convention.

---

## Prioritized fix list

- **P1** Introduce a shared `Motion` constant set (e.g. `quick=.easeInOut(0.15)`, `standard=.easeInOut(0.25)`, `scroll=.spring(0.4,0.85)`) and route all 9 sites through it.
- **P1** Animate tab switches (crossfade) in `ContentView:16` and `ChatTabContainerView:152`; add `.transition` to chat turn insertion (`ChatView:210`).
- **P2** Drive radii through `DesignTokens` at the 23 literal sites; replace the 4 deprecated `.cornerRadius(N)` calls; add `style:.continuous` everywhere; extend tokens with spacing members.
- **P2** Unify the two tab strips into one component (ideally backed by a native control) and animate the active highlight.
- **P2/P3** Standardize per-tab page/section header style; replace sub-10pt `.system(size:)` text with scalable semantic fonts.
