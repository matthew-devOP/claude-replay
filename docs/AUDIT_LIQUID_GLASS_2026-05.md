# Liquid Glass & Design Audit — Claude-MTW-Replay v1.0.0

Date: 2026-05-29
Scope: visual/design layer, read-only audit. 156 Swift sources.
Build target (swift/project.yml): macOS deploymentTarget **15.0** (line 5), `MACOSX_DEPLOYMENT_TARGET 15.0` (line 13), `xcodeVersion 16.0` (line 6), `SWIFT_VERSION 5.9` (line 12), `LSMinimumSystemVersion 14.0` (line 78).

---

## Executive verdict: Is Liquid Glass implemented?

**NO. Liquid Glass is not implemented at all — not even partially.** This is not a deficiency to "fix" so much as a fact dictated by the build target: the Liquid Glass APIs (`.glassEffect`, `GlassEffectContainer`, etc.) ship in the **macOS 26 / Xcode 26 SDK** and require a macOS 26 deployment target. This project builds against the **macOS 15 SDK with Xcode 16**, where those symbols do not exist. They cannot be present, and they aren't.

Evidence (exhaustive grep across all `*.swift`):

| Symbol searched | Occurrences |
|---|---|
| `glassEffect` | 0 |
| `GlassEffectContainer` | 0 |
| `glassEffectID` | 0 |
| `glassBackgroundEffect` | 0 |
| `buttonStyle(.glass)` / `.glassProminent` | 0 |
| `backgroundExtensionEffect` | 0 |
| `scrollEdgeEffect` | 0 |
| `liquidGlass` (case-insensitive) | 0 |
| `NSVisualEffectView` / `VisualEffectView` / `.visualEffect` / vibrancy | 0 |

The only `glass` substring in the codebase is the SF Symbol `magnifyingglass`, in exactly 3 files:
- Views/ContentView.swift:39
- Views/Transcript/TranscriptSearchBar.swift:7
- Views/Docs/DocsView.swift:34

The only system-material usage anywhere (3 sites, all `.regularMaterial`):
- Views/Dashboard/ActivityHeatmapView.swift:58 — `.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))`
- Views/Chats/SlashCommandPickerView.swift:54 — `.background(.regularMaterial)`
- Views/Chats/ChatView.swift:297 — `.background(.regularMaterial, in: Circle())` (floating regenerate button)

So the app's "translucency budget" is three small materials. Everything else is flat, opaque, theme-colored fills. This is a **flat, fully-opaque, custom-themed** design — the opposite end of the spectrum from Liquid Glass.

---

## Current design system inventory

The app does **not** rely on the standard macOS appearance/material stack. It implements its own self-contained palette system instead.

### Theming (the core of the design system)
- **Models/Theme.swift** — `struct Theme` with 17 named color roles (`bg`, `bgSurface`, `bgHover`, `text`, `textDim`, `textBright`, `accent`, `accentDim`, `green/blue/orange/red/cyan`, `border`, `toolBg`, `thinkingBg`) plus optional `extraCss`. `ThemeName` enum (Theme.swift:8) defines 8 built-in themes (claude-dark/light, tokyo-night, monokai, solarized-dark, github-light, dracula, bubbles). `isDark` derived at Theme.swift:60.
- **Services/ThemeService.swift** — single source of truth, loads `Resources/themes.json` lazily (ThemeService.swift:66-99) with a hardcoded 2-theme fallback (claude-dark, tokyo-night) so the app never crashes if the resource is missing. Also supports user-imported custom themes from disk (loadAllCustomThemes, ThemeService.swift:272) persisted as paths in UserDefaults.
- **Extensions/Color+Theme.swift** — `Color(hex:)` parser (3/6/8-digit) and `toHex()` round-trip (used by the HTML exporter). Clean, with a debug assert guarding against non-hex theme colors.
- Themes feed both the SwiftUI app and the HTML export path (`themeToCss`, ThemeService.swift:300) — the same palette renders the native UI and exported replays, which is a genuinely nice piece of design cohesion.

This is a **web-derived theming model** (CSS variables, same palette as the web replay viewer) ported to SwiftUI. It is deliberate and consistent, not ad-hoc.

### How color is applied
- ~22 `.background(appState.theme.*)` sites and ~13 `.foregroundColor/.foregroundStyle(appState.theme.*)` sites. Theme is injected via `@Environment(AppState.self)` and read as `appState.theme` everywhere — consistent access pattern.
- Full-pane opaque backgrounds via `theme.bg`: ChatView, PlansListView, SessionCompareView.
- Surfaces use `theme.bgSurface` (often at `.opacity(0.3–0.6)`) — e.g. ReplayControlsView.swift:41, ReplayTurnView.swift:29/85, MainTabBarView.swift:22.
- Borders drawn manually as `theme.border` strokes/rectangles (MainTabBarView.swift:24-26, ChatInputBarView.swift:282-285).
- Tints route through `theme.accent` for prominent controls (SessionRowView.swift:148, ChatInputBarView.swift:330, ChatSessionListView.swift:167, ModeToggleView.swift:36).

### Corner-radius / spacing consistency
Corner radii are reasonably disciplined: `6` (10 uses), `8` (8 uses), `4` (2), `12` (1, the drag-drop overlay in the App file). Two dominant radii (6 and 8) is fine, but there is **no shared constant** — every value is a magic number, so drift is possible over time.

### Native chrome
- NavigationSplitView sidebar (ContentView.swift:8) with `.searchable` (SidebarView.swift:33) and proper `.toolbar` placements — standard and correct.
- `.listStyle(.sidebar)` used in DocsSidebarView.swift:17 and PlansListView.swift:56.
- App entry: WindowGroup with `minWidth 900 / minHeight 600`, `.defaultSize(1200×800)`, `.defaultPosition(.center)`, rich `.commands` menus (Claude_MTW_ReplayApp.swift:14-143). No `.windowStyle`, no `.windowToolbarStyle`, no `.containerBackground` — defaults are used.

---

## Design polish / sanity check

### Strengths
- **Cohesive, intentional theme system** shared between native UI and HTML export. 8 curated themes + user-importable custom themes is well above the bar for a 1.0.
- **Strong accessibility** in interactive surfaces: ReplayControlsView and ChatInputBarView carry `.accessibilityLabel`/`.accessibilityHint`/`.accessibilityValue`, e.g. ReplayControlsView.swift:16-19, ChatInputBarView.swift:320-321/337-338.
- **Good keyboard story**: Cmd+1..N tab nav, Space/arrows for replay, Cmd+F/E, `?` cheatsheet (Claude_MTW_ReplayApp.swift:103-136, ContentView.swift:42).
- **Tasteful micro-interactions**: hover-revealed regenerate button with eased opacity (ChatView.swift:303-304); progress scrubber clipped to a Capsule (ReplayControlsView.swift:11).
- Standard NavigationSplitView + searchable sidebar reads as a native macOS app, not a ported web view.

### Issues / risks
1. **Flat opaque surfaces under a glass-era OS.** On macOS 15 (and especially under macOS 26 Tahoe), an app that paints every pane with an opaque custom `theme.bg` will look visibly "themed" rather than native — it ignores the desktop tint/translucency users now expect. This is the single biggest design gap, and it is the same gap that real Liquid Glass adoption would close.
2. **Custom tab strip instead of native chrome.** MainTabBarView (a hand-rolled `HStack` with accent-tinted rounded pills, MainTabBarView.swift:30-51) duplicates what `TabView`/toolbar tabs do natively. It works and looks fine, but it's the prime candidate that would *automatically* get glass on macOS 26 if it were a native `Tab` container.
3. **No shared style tokens.** Corner radii (6/8), opacities (0.3/0.5/0.6), and border widths are inline literals scattered across files. A `DesignTokens` enum would prevent drift and make a future glass migration far cheaper.
4. **Material/theme mixing is inconsistent.** Two pickers/overlays use `.regularMaterial` (SlashCommandPickerView, the ChatView regenerate button) while every other surface uses opaque `theme.bgSurface`. Visually these three materials will read differently from the rest of the app — they're the only translucent things on screen. Either commit to materials broadly or drop them for theme fills; the current split is arbitrary.
5. **Minimal depth language.** Only 2 `.shadow` uses total (ToastView, SlashCommandPickerView). Floating affordances (replay controls bar, chat input bar) sit flat against content with only a hairline border — fine today, but they are exactly the elements Liquid Glass is designed to lift.
6. **Sidebar translucency is implicit.** The sidebar gets its native vibrancy "for free" from `List` inside `NavigationSplitView`; the app never opts into or controls it (no `NSVisualEffectView`, no `scrollContentBackground`). That's acceptable, but it means the sidebar and the opaque detail pane have different material languages.

### Overall
This is a **polished, cohesive app with a deliberate custom design system** — not ad-hoc. But it is a *flat-themed* aesthetic, not a *native-material* one, and it is entirely orthogonal to Liquid Glass. Calling it "Liquid Glass implemented beautifully" would be inaccurate on both counts: it isn't Liquid Glass, and it isn't even using the standard macOS material stack beyond three incidental spots.

---

## Liquid Glass adoption plan

Liquid Glass cannot be added on the current target. Adoption is a real migration, not a sprinkle of modifiers.

### Phase 0 — Toolchain & target (prerequisite, gating)
- Bump to **Xcode 26 SDK** (`xcodeVersion: "26.0"` in swift/project.yml:6).
- Add a macOS 26 build capability while keeping the deployment floor. Practical pattern: keep `deploymentTarget.macOS: "15.0"` / `MACOSX_DEPLOYMENT_TARGET 15.0` (project.yml:5/13) and gate every glass call behind `if #available(macOS 26, *)`. Do **not** raise the floor unless you intend to drop macOS 14/15 users (see Risks).
- Note: `LSMinimumSystemVersion: "14.0"` (project.yml:78) currently advertises macOS 14 support even though the code targets 15 — reconcile this regardless.

### Phase 1 — Availability-guard pattern (the foundation)
Centralize the fallback so glass appears in one helper, not scattered `#available` checks. Add to Extensions/ (e.g. a `View+Glass.swift`):

```swift
extension View {
    /// Applies Liquid Glass on macOS 26+, falls back to the existing
    /// theme-fill treatment on macOS 15.
    @ViewBuilder
    func appGlass<S: Shape>(in shape: S, fallback: Color) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(fallback, in: shape)
        }
    }
}
```

Every surface that today writes `.background(appState.theme.bgSurface, in: RoundedRectangle(cornerRadius: 8))` becomes `.appGlass(in: RoundedRectangle(cornerRadius: 8), fallback: appState.theme.bgSurface)`. macOS 15 behavior is byte-for-byte unchanged.

### Phase 2 — Where glass goes (highest impact first)
1. **Floating control bars** — the clearest wins:
   - Views/Replay/ReplayControlsView.swift:41 (`.background(appState.theme.bgSurface)`) → `appGlass(...)` so the transport bar floats over the replay content. Wrap the button cluster (lines 21-39) in a `GlassEffectContainer` so the play/prev/next group merges into one glass shape.
   - Views/Chats/ChatInputBarView.swift:281-285 (the input field's `bgSurface` fill + border overlay) → glass capsule/rounded-rect. The send/stop button (lines 308-339) is a perfect `buttonStyle(.glassProminent)` candidate, tinted `appState.theme.accent`.
2. **Search bars** — Views/Transcript/TranscriptSearchBar.swift and Views/Docs/DocsView.swift search rows → glass capsule containers.
3. **Tab strip** — Views/Shared/MainTabBarView.swift. Best path: replace the hand-rolled HStack with a native `Tab`-based container so it inherits toolbar glass automatically on macOS 26; failing that, give the active-pill background (MainTabBarView.swift:44-47) `glassEffect` with `glassEffectID` so the selection indicator animates between tabs.
4. **Overlays already using material** — Views/Chats/SlashCommandPickerView.swift:54 and the ChatView regenerate button (ChatView.swift:297) should migrate `.regularMaterial` → `.glassEffect(...)` for consistency once on macOS 26.
5. **Toolbar** — ContentView.swift:29-50 toolbar items get glass automatically under macOS 26 with no code change; just verify the custom `SpinnerVerbView` principal item reads well against glass.
6. **Window chrome (optional)** — consider `.containerBackground` / a glass `.windowStyle` on the WindowGroup (Claude_MTW_ReplayApp.swift:14) so the whole window participates, and stop painting opaque `theme.bg` on full panes (ChatView, PlansListView, SessionCompareView) when on macOS 26 — let glass and the desktop show through.

### Phase 3 — Token cleanup (do this regardless)
Introduce a `DesignTokens` enum (corner radii 6/8, the standard opacities, border width) so the glass migration touches named constants instead of dozens of literals. This is the cheapest single thing to do now to de-risk a future migration.

### Risks
- **You lose macOS 14/15 users for the glass look** — glass renders only on macOS 26. With the `#available` guard those users get today's flat theme (acceptable). If anyone instead *raises* the deployment floor to macOS 26, the app stops launching on macOS 14/15 entirely, contradicting `LSMinimumSystemVersion 14.0` (project.yml:78). Keep the floor; gate the glass.
- **Theme vs. glass tension.** Liquid Glass derives tint from content/desktop, not from a fixed palette. The app's whole identity is its 8 opaque themes. Heavy glass + a strong custom palette can fight each other (glass washes out theme colors). Decide deliberately: glass for *chrome/floating controls only* (recommended) vs. glass *everywhere* (would dilute the theme system that is currently the app's strongest asset).
- **Custom tab strip rework** is the most invasive change; if MainTabBarView is replaced with a native container, re-test the Cmd+1..N shortcuts (Claude_MTW_ReplayApp.swift:104-107) and the `switchTab` flow.
- **CI/toolchain**: Xcode 26 may not be available on the current build agents; verify before committing the `xcodeVersion` bump.

---

## Bottom line
Liquid Glass is **not implemented** and **cannot be** on the macOS 15 / Xcode 16 target — confirmed by zero occurrences of every glass API. What exists instead is a clean, deliberate, opaque custom-theme design system shared with the HTML exporter: polished and cohesive, but flat and not material-native. True glass adoption is a real migration (Xcode 26 SDK + availability-gated `.glassEffect`/`GlassEffectContainer` on floating controls, input/search bars, and the tab strip), best done chrome-first to preserve the theme system, and must keep the `#available(macOS 26, *)` fallback to avoid dropping macOS 14/15 users.
