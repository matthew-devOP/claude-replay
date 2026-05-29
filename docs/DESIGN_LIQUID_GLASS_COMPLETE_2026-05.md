# Liquid Glass — Completeness & Correctness Audit (2026-05)

App: Claude-MTW-Replay 1.0.0 · Deployment target macOS 15.0 · Builds on Xcode 26.3 (SDK includes Liquid Glass).
Scope: read-only DESIGN audit of Liquid Glass adoption. All findings cite `file:line`.

---

## 1. Executive verdict

**Glass is NOT complete. It is roughly 15–20% of where a tasteful, complete adoption should land.**

The helper (`Extensions/GlassStyle.swift`) is mostly correct and the guard strategy (compile `#if compiler(>=6.2)` + runtime `#available(macOS 26.0, *)`) is sound. But adoption is a thin first pass: glass was sprinkled onto 6 small leaf surfaces, while the surfaces that *define* the app's chrome on macOS 26 — the hand-rolled main tab bar, the toolbar, sidebar, sheets, the chat input bar, toasts, and all popovers/menus — get **no** glass at all. Critically, `glassGroup(...)` (the `GlassEffectContainer` wrapper) is **defined but never called** anywhere in the codebase, so no glass clusters can blend/morph — the headline feature of Liquid Glass is unused.

Net: the plumbing is right, the coverage is shallow, and the one differentiating capability (grouping/morphing) is dead code.

---

## 2. Helper-correctness findings (`Extensions/GlassStyle.swift`)

| # | Finding | Verdict |
|---|---------|---------|
| H1 | `self.glassEffect(.regular, in: shape)` (line 26) — API name, `.regular` `Glass` value, and `in:` shape label are the correct macOS 26 signature. | ✅ Correct |
| H2 | Compile guard `#if compiler(>=6.2)` + runtime `#available(macOS 26.0, *)` with a `.background(fallback, in:)` fallback (lines 24–32). One binary runs macOS 14→26; Xcode 16 still builds. | ✅ Correct |
| H3 | Default fallback is `.regularMaterial` (lines 37, 46). Reasonable — a vibrant material is the closest pre-26 analogue to glass. | ✅ Acceptable |
| H4 | `glassGroup(spacing:)` (lines 52–63) wraps content in `GlassEffectContainer`. **Defined but referenced ZERO times** in the app (grep: only the definition matches). Without it, sibling glass shapes never merge/morph — the core Liquid Glass behavior is absent. | ❌ Dead code / core feature unused |
| H5 | No interactive variant. Every applied site is a *control* (transport buttons, regenerate button, search fields), yet glass is applied as a passive background. Apple recommends `.glassEffect(.regular.interactive(), in:)` for tappable glass, or `.buttonStyle(.glass)` for buttons. The helper offers neither, so controls don't get the press/hover light response. | ❌ Gap |
| H6 | `appGlass(in:)` applies glass but does **not** clip; callers must add `.clipShape` separately (done in SlashCommandPicker:55 and DocsView:44, but NOT in TranscriptSearchBar:15, ReplayControls:39 which rely on the shape being its own clip). Inconsistent — `glassEffect(in:)` shapes its own effect but doesn't clip child content, so e.g. a glass capsule with non-clipped children can bleed. Minor but worth a documented convention. | ⚠️ Minor |
| H7 | No `glassEffectID(_:in:)` / `@Namespace` support. Needed for morph transitions between grouped glass elements (e.g. transport ↔ expanded controls). Acceptable to defer, but note it's the partner API to H4. | ⚠️ Deferred |

**Helper summary: correct as far as it goes (H1–H3 good), but it under-serves the design — no interactive glass (H5) and the grouping primitive is dead (H4).**

---

## 3. Coverage-gap table

Surfaces that float above content and SHOULD carry glass on macOS 26 but currently don't. "Treatment" = recommended modifier, all behind `appGlass`/`glassGroup` so the macOS 15 fallback is preserved.

| Surface | File:line | Current | Recommended treatment |
|---|---|---|---|
| **Main tab bar (hand-rolled)** | `Views/Shared/MainTabBarView.swift:13–28` | Opaque `appState.theme.bgSurface.opacity(0.6)` + hairline | **Biggest gap.** Apple wants a native `TabView`/`Tab` so the bar gets automatic glass + scroll-edge effects. Short of refactor: wrap the `HStack` in `.glassGroup()` and apply `.appGlass(in: Capsule())` to the active-tab pill (currently a plain `RoundedRectangle.fill`, line 44–47) so tabs read as glass segments. |
| **Detail toolbar** | `Views/ContentView.swift:29–50` | Plain `.toolbar` items | On macOS 26 native `.toolbar` gets glass automatically — verify it isn't suppressed. Ensure no opaque background sits behind the toolbar. The principal `SpinnerVerbView` and `primaryAction` buttons should ride the system glass bar; consider `.buttonStyle(.glass)` on the search/help buttons (lines 36–48). |
| **Sidebar** | `Views/Sidebar/SidebarView.swift` + `Views/ContentView.swift:8` (`NavigationSplitView`) | Default | `NavigationSplitView` sidebars get glass automatically on 26; confirm no opaque `.background` overrides it. No code change likely needed beyond removing any opaque fill. |
| **Chat input bar container** | `Views/Chats/ChatInputBarView.swift:32–38` (`VStack`…`.padding(12)`) and `inputRow` `.background(theme.bgSurface)` line 281 | Opaque surface + bordered controls | The input bar is a floating chrome dock — prime glass candidate. Apply `.appGlass(in: RoundedRectangle(cornerRadius: cornerLarge), fallback: theme.bgSurface)` to the outer container and `.glassGroup()` around the controls row (mode toggle + prefix buttons + verbose). Use `.buttonStyle(.glass)` for prefix buttons (lines 180–191). |
| **Toast** | `Views/Shared/ToastView.swift:7–18` | Solid `Color.red/green.opacity(0.9)` + shadow | Floating overlay = textbook glass. Replace solid fill with `.appGlass(in: Capsule(), fallback: <tint>)` and tint via `.tint(...)` so the message reads on glass while keeping the colored fallback on 15. |
| **Slash picker popover** | `Views/Chats/SlashCommandPickerView.swift:49` | Rows have `Color.secondary.opacity(0.1)` background *inside* a glass container (line 54) | Glass on container is correct; the per-row opaque fill (line 49) is glass-on-near-opaque. Drop the row fill, use `.glassEffect`-friendly hover highlight, and add `.glassGroup()` if multiple floating pickers ever coexist. (See misuse M2.) |
| **Session hover popover** | `Views/Dashboard/SessionRowView.swift:32` (`.popover`) | System popover | macOS 26 popovers get glass automatically; verify `hoverPopoverContent` has no opaque background fighting it. |
| **Sheets (Export/Search/Shortcuts/Compare/Chain/Preview/Permission)** | `ContentView.swift:52–54`; `ChatInputBarView.swift:84,87`; `DashboardView.swift:50`; `SessionTableView.swift:60`; `ChatView.swift:47,53` | Plain `.sheet` with opaque `.padding/.frame` content | Sheets get system glass on 26. No glass *background* should be hand-added (that would be misuse), but ensure inner containers (e.g. `GlobalSearchView` line 23 `.padding().frame`) don't paint an opaque background that defeats the system treatment. |
| **Empty-state / splash overlays** | `Views/Shared/EmptyStateView.swift:9`; `Views/Shared/SplashEmptyView.swift:46` | Plain `maxWidth/maxHeight` fill | These are content backdrops, NOT floating chrome — **leave un-glassed** (glassing a full pane is misuse). Listed here only to record the deliberate exclusion. |
| **Regenerate FAB** | `Views/Chats/ChatView.swift:297` | Has `.appGlass(in: Circle())` ✅ | Already glass, but it's a lone floating button with no `.interactive()` and no group. Add `.glassEffect(.regular.interactive(), in: Circle())` via an interactive helper; if more FABs appear, wrap in `.glassGroup()`. |
| **Transport cluster + speed/toggles** | `Views/Replay/ReplayControlsView.swift:24–46` | Transport capsule has glass (line 39); the adjacent Picker + 2 Toggles (lines 42–46) do NOT, and nothing is grouped | Wrap the whole `HStack` (line 21) in `.glassGroup()` and give the speed Picker + Thinking/Tools toggles matching glass so the transport cluster blends with the controls instead of being one lone glass island next to bare controls. (See grouping §5.) |
| **Bookmark bar** | `Views/Replay/BookmarkBarView.swift` | Default | Floating-ish strip above replay — candidate for `.appGlass` if it overlays content. |

---

## 4. Misuse findings

| # | Issue | File:line | Why it's a problem |
|---|---|---|---|
| M1 | Lone glass island next to bare controls | `ReplayControlsView.swift:39` | The transport capsule is glass, but the sibling speed Picker + toggles (42–46) are plain and nothing is grouped. Visually one glass blob floating beside flat controls — Apple's guidance is to group related floating controls so they share one glass surface. |
| M2 | Glass-on-near-opaque (stacked surfaces) | `SlashCommandPickerView.swift:49` inside glass at line 54 | Each row paints `Color.secondary.opacity(0.1)` *on top of* the glass container. Translucent-on-glass muddies the effect. Remove the row fill; let glass show through, use a subtle hover state instead. |
| M3 | Glass tooltip over a dense grid may reduce legibility | `ActivityHeatmapView.swift:58` | Default `.regularMaterial`/glass tooltip over a multi-colored heatmap can wash out. Acceptable, but verify contrast; consider `.regular` glass is fine, just ensure text stays legible (it floats, so probably OK). |
| M4 | Opaque fills that will fight system glass once toolbars/sheets/sidebar adopt it | `MainTabBarView.swift:22` (`bgSurface.opacity(0.6)`), `ChatInputBarView.swift:281` (`theme.bgSurface`) | Not misuse *today* (no glass there yet), but these opaque backgrounds must be removed/softened when glass is applied, or they'll defeat it. Flagged so the completion plan removes them. |

**No instance found of glass applied to a genuinely large opaque content pane** (empty states correctly remain plain). Good restraint there.

---

## 5. Grouping / morphing

`GlassEffectContainer` (via `glassGroup`) is **never used** (H4). Concrete places it's needed:

1. **Replay transport + controls** — `ReplayControlsView.swift:21` outer `HStack`. Wrap in `.glassGroup(spacing: 16)` and make the Picker/Toggles glass so the cluster merges.
2. **Chat input controls row** — `ChatInputBarView.swift:146` `controlsRow`. Mode toggle + 3 prefix buttons + verbose toggle should share one glass container.
3. **Main tab bar** — `MainTabBarView.swift:14` `HStack`. The tab pills should be sibling glass shapes in a container so the active pill can morph between tabs (`glassEffectID` + `@Namespace`).
4. **Toolbar primary-action button group** — `ContentView.swift:33` `ToolbarItemGroup`. If using custom glass buttons, group them; otherwise rely on system toolbar glass.

Without containers, any two nearby glass shapes render as independent panes that don't blend — the adoption looks like "material with extra steps," not Liquid Glass.

---

## 6. Prioritized completion plan

All changes stay behind `appGlass`/`glassGroup` so the macOS 15 fallback is byte-for-byte preserved.

**P0 — make grouping real (unlocks the core effect)**
1. `Extensions/GlassStyle.swift`: add an **interactive** helper, e.g. `appGlassInteractive(in:fallback:)` → `glassEffect(.regular.interactive(), in:)` (macOS 26) / `.background` fallback. Add `appGlassID(_:in:)` wrapping `glassEffectID` for morphing.
2. `Views/Replay/ReplayControlsView.swift:21`: wrap the transport `HStack` in `.glassGroup(spacing: 16)`; give the speed Picker + Thinking/Tools toggles `.appGlass(in: Capsule())` so the cluster blends (fixes M1).

**P1 — chrome that defines the macOS 26 look**
3. `Views/Shared/MainTabBarView.swift`: prefer migrating to native `TabView`/`Tab` for automatic glass + scroll-edge. If keeping the custom bar: remove the opaque `bgSurface.opacity(0.6)` (line 22, M4), wrap the `HStack` in `.glassGroup()`, and make the active-tab pill `.appGlass(in: Capsule())` with `glassEffectID` for the morph.
4. `Views/Chats/ChatInputBarView.swift`: glass the outer container (`.appGlass(in: RoundedRectangle(cornerRadius: .cornerLarge), fallback: theme.bgSurface)`), drop the opaque `inputRow` background (line 281, M4), `.glassGroup()` the controls row, `.buttonStyle(.glass)` on prefix buttons (180–191).
5. `Views/ContentView.swift:29–50` & `SidebarView.swift`: confirm native toolbar + split-view glass isn't suppressed by opaque backgrounds; apply `.buttonStyle(.glass)` to the toolbar search/help buttons.

**P2 — floating accents**
6. `Views/Shared/ToastView.swift:7–18`: replace solid fill with `.appGlass(in: Capsule(), fallback: tint)` + `.tint`.
7. `Views/Chats/SlashCommandPickerView.swift:49`: remove per-row opaque fill (M2); keep container glass.
8. `Views/Chats/ChatView.swift:297`: switch regenerate button to the interactive glass helper.

**P3 — verify, don't add**
9. Sheets/popovers (`ContentView.swift:52–54`, `SessionRowView.swift:32`, the chat sheets): do NOT hand-add glass backgrounds; instead remove any opaque inner backgrounds (e.g. `GlobalSearchView.swift:23`) so system glass shows.
10. Keep `EmptyStateView` / `SplashEmptyView` un-glassed (content, not chrome).

**Guardrails:** never glass a full content pane; never stack translucent-on-glass; always pass a `fallback` that matches the current macOS 15 look; group nearby glass controls.
