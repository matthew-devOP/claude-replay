# Plan de improvements — Aplicație Swift Claude-MTW-Replay (v1.0 / DMG 0.8.1)

> Documentul este derivat din [AUDIT_SWIFT.md](AUDIT_SWIFT.md), [AUDIT_WEB.md](AUDIT_WEB.md) și [AUDIT_DIFF.md](AUDIT_DIFF.md). Toate referințele `file:line` au fost confirmate in-place prin lectura codului din `/Users/anonymous-dd/work/claude-replay/swift/Claude-MTW-Replay/`.

---

## Sumar

- **Starea curentă:** aplicația livrează la `0.8.1` paritate funcțională cu web pe parser / redaction / themes / discovery / export / replay / stats / git, plus feature-ul propriu **Chats live** prin sidecar `@anthropic-ai/claude-agent-sdk@0.1.5`. Există însă **18 lipsuri concrete** documentate ([AUDIT_SWIFT.md § Lipsuri/observații](AUDIT_SWIFT.md#lipsuriobservații)), inclusiv 6 stub-uri vizibile direct utilizatorului.
- **Dublu scop:** (A) închiderea integrală a backlog-ului de paritate cu web (extract, FileWatcher wired, custom themes, OG defaults, bulk include/exclude editor, session concat) și (B) ridicarea tab-ului **Chats** la nivel de client production-ready cu persistență, forking, MCP, model picker, slash commands, attachments, multi-tab.
- **Versiune mismatch documentat:** `Info.plist` 1.0 ↔ `MARKETING_VERSION` 1.0.0 ↔ DMG `0.8.1` ↔ sidecar `0.8.0`. Trebuie ales un singur source-of-truth (`project.yml`) și sincronizat cu CHANGELOG dedicat Swift ([AUDIT_DIFF.md § Decalaje](AUDIT_DIFF.md#decalaje-de-versiune-și-sincronizare)).
- **Estimare totală efort:** **~62–84 zile-om senior Swift/macOS** (≈12 săptămâni dacă merge 1 dezvoltator solo, ≈6 săptămâni cu o pereche). Plus ~6–8 zile pentru release engineering (notarization, signing, Sparkle).
- **Ordinea recomandată de execuție:** P0 (stub-uri vizibile) → P1 paritate web (FileWatcher wired, extract UI, custom themes, OG, concat) → P2 deduplicare cod + testing → P3 polish UX → **Chats Excellence** (cel mai mare lift) → Release engineering.
- **Riscuri majore:** (1) regresie pe parser dacă nu adăugăm test coverage (Swift are 0 teste pentru `TranscriptParser`, web are 46); (2) sidecar duplicat în două copii pe disk; (3) `WKWebView` PDF export e fragil pe documente lungi; (4) lipsa notarization Apple blochează distribuția "double-click → run" pe Mac-uri din afara dev pool.
- **Asumpție arhitecturală:** continuăm pe SwiftUI + MVVM + SwiftData; NU rescriem nimic. Toate îmbunătățirile sunt incrementale peste cod existent.

---

## Status paritate cu web — scoreboard

Legendă status: ✅ Done · 🟡 Partial · ❌ Missing · 🐛 Buggy · ⚪ Web-only intentional.

| # | Feature | Status | Sursă audit | Effort estimat |
|---|---|---|---|---|
| 1 | Parser Claude Code | ✅ | [AUDIT_DIFF § Parser](AUDIT_DIFF.md#parser-transcripte) | — |
| 2 | Parser Cursor | ✅ | [AUDIT_DIFF § Parser](AUDIT_DIFF.md#parser-transcripte) | — |
| 3 | Parser Codex CLI (event-based) | ✅ | [AUDIT_SWIFT § Parser](AUDIT_SWIFT.md#parser-și-formate-suportate) | — |
| 4 | Redaction (11 patterns) | 🟡 dublură | [AUDIT_SWIFT § Lipsuri 13](AUDIT_SWIFT.md#lipsuriobservații) | 0.5z |
| 5 | Custom redact rules `--redact key=value` | ❌ | [AUDIT_WEB § CLI](AUDIT_WEB.md#funcționalități--cli) | 1z |
| 6 | Themes 8 built-in | ✅ dublure | [AUDIT_SWIFT § Lipsuri 14](AUDIT_SWIFT.md#lipsuriobservații) | — |
| 7 | `--theme-file` custom JSON | ❌ | [AUDIT_DIFF § Doar în Web](AUDIT_DIFF.md#doar-în-web-lipsă-în-swift) | 1z |
| 8 | Discovery 3 root-uri (Claude/Cursor/Codex) | ✅ | [AUDIT_SWIFT § Discovery](AUDIT_SWIFT.md#session-discovery--resolver) | — |
| 9 | Multi-account auto-discovery `~/.claude-*` | ✅ | [AUDIT_SWIFT § Multi-cont](AUDIT_SWIFT.md#funcționalități-multi-cont) | — |
| 10 | Dashboard project header + heatmap | ✅ | [AUDIT_SWIFT § Dashboard](AUDIT_SWIFT.md#funcționalități--dashboard) | — |
| 11 | Sessions table sortable | ✅ | [AUDIT_SWIFT § Dashboard](AUDIT_SWIFT.md#funcționalități--dashboard) | — |
| 12 | Editor turn (text edit + exclude) | ✅ | [AUDIT_SWIFT § Editor](AUDIT_SWIFT.md#funcționalități--editor) | — |
| 13 | Editor — Bulk Include All / Exclude All | ❌ | [AUDIT_SWIFT § Editor "Lipsuri funcționale"](AUDIT_SWIFT.md#funcționalități--editor) | 0.5z |
| 14 | Editor — Bulk select multi-turn (Cmd+Click) | ❌ | [AUDIT_SWIFT § Editor](AUDIT_SWIFT.md#funcționalități--editor) | 1z |
| 15 | Replay native player | ✅ | [AUDIT_SWIFT § Replay](AUDIT_SWIFT.md#funcționalități--replay) | — |
| 16 | Replay — Bookmark add (B hotkey) | ❌ | [AUDIT_SWIFT § Lipsuri 9](AUDIT_SWIFT.md#lipsuriobservații) | 0.5z |
| 17 | Tool grouping threshold | 🐛 inconsistent (web 1+, Swift 5+) | [AUDIT_DIFF § Implementări divergente](AUDIT_DIFF.md#implementări-divergente-ale-acelorași-funcționalități) | 0.5z |
| 18 | Stats — overview + chart + lists | ✅ | [AUDIT_SWIFT § Stats](AUDIT_SWIFT.md#funcționalități--stats) | — |
| 19 | Git read-only summary | ✅ | [AUDIT_SWIFT § Git](AUDIT_SWIFT.md#funcționalități--git-integration) | — |
| 20 | Search (substring) per proiect | ✅ | [AUDIT_SWIFT § Search](AUDIT_SWIFT.md#funcționalități--search) | — |
| 21 | Search — cross-project (claude+cursor+codex) | 🟡 doar claude | [AUDIT_SWIFT § Search](AUDIT_SWIFT.md#funcționalități--search) | 1z |
| 22 | Export HTML | 🐛 buton sheet TODO | [AUDIT_SWIFT § Lipsuri 4](AUDIT_SWIFT.md#lipsuriobservații) | 0.5z |
| 23 | Export Markdown | ✅ via MD button | [AUDIT_SWIFT § Export](AUDIT_SWIFT.md#funcționalități--export) | — |
| 24 | Export PDF (WKWebView) | ✅ | [AUDIT_SWIFT § Export](AUDIT_SWIFT.md#funcționalități--export) | — |
| 25 | Import HTML (`HTMLExtractor` UI) | 🟡 API exists, no UI | [AUDIT_DIFF Rec. 1](AUDIT_DIFF.md#recomandări-pentru-paritate-completă) | 1z |
| 26 | Favorites — sidebar listing | 🐛 stub | [AUDIT_SWIFT § Lipsuri 2](AUDIT_SWIFT.md#lipsuriobservații) | 1z |
| 27 | Tags — sidebar listing + assign UI | ❌ stub | [AUDIT_SWIFT § Lipsuri 3](AUDIT_SWIFT.md#lipsuriobservații) | 2z |
| 28 | Plans tab | ✅ | [AUDIT_SWIFT § Dashboard](AUDIT_SWIFT.md#funcționalități--dashboard) | — |
| 29 | CLAUDE.md / MEMORY.md tabs | ✅ | [AUDIT_SWIFT § Dashboard](AUDIT_SWIFT.md#funcționalități--dashboard) | — |
| 30 | Session compare side-by-side | 🟡 no diff highlight | [AUDIT_SWIFT § Lipsuri 6](AUDIT_SWIFT.md#lipsuriobservații) | 2z |
| 31 | FileWatcher → live update sessions | 🟡 service exists, not wired | [AUDIT_SWIFT § Lipsuri 8](AUDIT_SWIFT.md#lipsuriobservații) | 1.5z |
| 32 | Multi-input session concatenation | ❌ | [AUDIT_DIFF § Doar în Web](AUDIT_DIFF.md#doar-în-web-lipsă-în-swift) | 1.5z |
| 33 | OG meta tags export | ✅ flags exist | [AUDIT_SWIFT § Export](AUDIT_SWIFT.md#funcționalități--export) | — |
| 34 | Bookmarks `--mark` / `--bookmarks FILE` | ❌ | [AUDIT_DIFF § Doar în Web](AUDIT_DIFF.md#doar-în-web-lipsă-în-swift) | 0.5z |
| 35 | MenuBar (NSStatusItem) | ❌ dir gol | [AUDIT_SWIFT § Lipsuri 1](AUDIT_SWIFT.md#lipsuriobservații) | 2z |
| 36 | KeyboardShortcuts panel (real labels) | 🐛 listează `⌘1-6`, real `⌘1-7` | [AUDIT_SWIFT § Lipsuri 18](AUDIT_SWIFT.md#lipsuriobservații) | 0.2z |
| 37 | Settings — Locate Node/Claude binary picker | 🟡 API exists, no UI | [AUDIT_SWIFT § Lipsuri 7](AUDIT_SWIFT.md#lipsuriobservații) | 0.5z |
| 38 | Chats — live SDK | ✅ | [AUDIT_SWIFT § Chats](AUDIT_SWIFT.md#funcționalități--chats-chat-interactiv) | — |
| 39 | Chats — Split-view two chats | ❌ disabled | [AUDIT_SWIFT § Lipsuri 5](AUDIT_SWIFT.md#lipsuriobservații) | 3z |
| 40 | Chats — persistență istoric local | ❌ | (gap nou) | 3z |
| 41 | Chats — model picker | ❌ | (gap nou) | 1z |
| 42 | Chats — MCP integration | ❌ | (gap nou) | 4z |
| 43 | Chats — slash commands `.claude/commands/` | ❌ | (gap nou) | 2z |
| 44 | Chats — attachments preview | ❌ | (gap nou) | 2z |
| 45 | Terminal embedded (lazygit) | ⚪ web-only | [AUDIT_DIFF § Doar în Web](AUDIT_DIFF.md#doar-în-web-lipsă-în-swift) | — |
| 46 | Docker distribution | ⚪ web-only | [AUDIT_DIFF § Distribuție](AUDIT_DIFF.md#decalaje-de-versiune-și-sincronizare) | — |
| 47 | npm CLI binary | ⚪ web-only | [AUDIT_DIFF § Doar în Web](AUDIT_DIFF.md#doar-în-web-lipsă-în-swift) | — |
| 48 | CSRF privacy check | ⚪ irelevant pe macOS native | — | — |

**Recap:** 18 features ✅ done · 8 features 🟡 partial · 17 features ❌ missing · 4 ⚪ intentional web-only · 4 🐛 buggy.

---

## P0 — Bloquantes / Stub-uri vizibile utilizatorului

Lucrurile care fac aplicația să arate nefinisată. Toate sunt vizibile la prima rulare.

### P0.1 — `FavoritesSectionView` hardcoded "No favorites yet"

- **File:line:** `swift/Claude-MTW-Replay/Views/Sidebar/FavoritesSectionView.swift:2-9`
- **Ce face acum:** afișează literal `Text("No favorites yet")` indiferent de DB.
- **Ce trebuie:** folosește `appState.favoritesVM.favorites` (instanță deja există în `AppState`), iterează `ForEach`, fiecare rând afișează `sessionId.prefix(12)` + preview, click → `appState.selectSession(path:)`. Trebuie și `.contextMenu` cu "Remove from Favorites".
- **Sursă audit:** [AUDIT_SWIFT § Lipsuri 2](AUDIT_SWIFT.md#lipsuriobservații)
- **Effort:** 1 zi (UI + sortare + empty state real).

### P0.2 — `TagsSectionView` hardcoded "No tags yet"

- **File:line:** `swift/Claude-MTW-Replay/Views/Sidebar/TagsSectionView.swift:2-8`
- **Ce face acum:** stub identic cu Favorites; UI lipsește complet.
- **Ce trebuie:** (a) `TagsViewModel` nou care expune `tagsGrouped: [String: [TaggedSession]]` peste `DataStore.shared.getAllTaggedSessions()`; (b) `DisclosureGroup` per tag cu sesiunile aferente; (c) context-menu "Remove tag" + drag-drop session→tag; (d) integrează `TagChipView` în `SessionTableView` ca să afișezi tag-urile per rând.
- **Sursă audit:** [AUDIT_SWIFT § Lipsuri 3](AUDIT_SWIFT.md#lipsuriobservații)
- **Effort:** 2 zile.

### P0.3 — `ExportSheet` buton "Export" cu `/* TODO */`

- **File:line:** `swift/Claude-MTW-Replay/Views/Export/ExportSheet.swift:15`
- **Ce face acum:** `Button("Export") { Task { /* TODO */ dismiss() } }` — închide sheet-ul fără să apeleze `vm.export(...)`.
- **Ce trebuie:** apel concret `await vm.export(turns: appState.currentTurns ?? [], options: makeExportOptions())` urmat de `dismiss()` doar la succes; propagare `vm.errorMessage` într-un `.alert`. Plus toggle Redact, `userLabel`/`assistantLabel` fields.
- **Sursă audit:** [AUDIT_SWIFT § Lipsuri 4](AUDIT_SWIFT.md#lipsuriobservații)
- **Effort:** 0.5 zile.

### P0.4 — `Views/MenuBar/` directorul gol

- **File:line:** `swift/Claude-MTW-Replay/Views/MenuBar/` (0 fișiere)
- **Ce face acum:** nimic — declarat în audit ca placeholder.
- **Ce trebuie:** decizia minimă: ori (a) eliminăm directorul ca să nu inducă în eroare (5 minute), ori (b) implementăm un `NSStatusItem` real cu meniu rapid (Open last session, Open project, Settings, Quit) + listă "Recent Sessions" (max 10). Recomandare: (b), e o feature mică care iese vizibil în bara macOS.
- **Sursă audit:** [AUDIT_SWIFT § Lipsuri 1](AUDIT_SWIFT.md#lipsuriobservații)
- **Effort:** 0.1 zile (a) sau 2 zile (b).

### P0.5 — Split-view chat dezactivat

- **File:line:** `swift/Claude-MTW-Replay/Views/Chats/ChatSessionListView.swift:157-163`
- **Ce face acum:** `Button {}.disabled(true).help("Split-view will land in v0.8.1-swift")`. Suntem deja la 0.8.1 → fie livrăm, fie ștergem butonul.
- **Ce trebuie:** vezi Chats — Plan de excelență § "Multi-tab chats". Implementare: `ChatsView` → `HSplitView { ChatView(sessionPath: a) ChatView(sessionPath: b) }` cu picker per-pane. Necesită ca `ChatViewModel` să nu mai țină state global (deja e instanțiat per-view, OK).
- **Sursă audit:** [AUDIT_SWIFT § Lipsuri 5](AUDIT_SWIFT.md#lipsuriobservații)
- **Effort:** 3 zile (vezi Roadmap Chat M2).

### P0.6 — `FileWatcher` neconectat la UI

- **File:line:** `swift/Claude-MTW-Replay/Services/FileWatcher.swift:151-183` (utilitate gata) — niciun call-site în ViewModels.
- **Ce face acum:** clasa există, `watchSessionDirectories(handler:)` returnează `[FileWatcher]` corect, dar nimic în UI nu o instanțiază.
- **Ce trebuie:** `ProjectListViewModel.onAppear` instanțiază watchers și pe event `.created`/`.deleted`/`.modified` apelează `await loadProjects(...)` cu debounce 500ms. Similar pentru `SessionListViewModel` când e un proiect selectat. Reține watchers în `Set<FileWatcher>` la nivel de ViewModel ca să se elibereze corect.
- **Sursă audit:** [AUDIT_SWIFT § Lipsuri 8](AUDIT_SWIFT.md#lipsuriobservații), [AUDIT_DIFF Rec. 2](AUDIT_DIFF.md#recomandări-pentru-paritate-completă)
- **Effort:** 1.5 zile.

### P0.7 — `KeyboardShortcutsView` listă incorectă (`⌘1-6` vs real `⌘1-7`)

- **File:line:** `swift/Claude-MTW-Replay/Views/Shared/KeyboardShortcutsView.swift` (verifică liniile cu `⌘`)
- **Ce face acum:** afișează doar 6 taburi când realitatea e 7 (Dashboard/Chats/Replay/Transcript/Editor/Stats/Git).
- **Ce trebuie:** generează lista din `AppTab.allCases` (truth-driven), nu mai hard-code-uia.
- **Sursă audit:** [AUDIT_SWIFT § Lipsuri 18](AUDIT_SWIFT.md#lipsuriobservații)
- **Effort:** 0.2 zile.

### P0.8 — `SidecarLocator` Settings UI pentru "Locate manually"

- **File:line:** `swift/Claude-MTW-Replay/Services/SidecarLocator.swift:78-79` (API exists) — `Views/Shared/SettingsView.swift:1-27` (no picker exposed).
- **Ce face acum:** dacă `node` nu e găsit în pathurile standard, aplicația eșuează silent în Chats. API-ul de override (`setNodeBinary(_:)`) există dar nu e expus.
- **Ce trebuie:** secțiune nouă "Sidecar" în Settings: două câmpuri `Path to node`, `Path to claude` + butoane "Locate…" (NSOpenPanel filtrat la executables) + status (verde dacă găsit, roșu altfel). Toate persistate în UserDefaults.
- **Sursă audit:** [AUDIT_SWIFT § Lipsuri 7](AUDIT_SWIFT.md#lipsuriobservații)
- **Effort:** 0.5 zile.

### P0.9 — Speed slider range inconsistent (sheet 0.5-10, VM 0.5-20)

- **File:line:** `Views/Export/ExportSheet.swift:13` (`0.5...10`) vs `ViewModels/ReplayViewModel.swift:speedSteps` (`[0.5, 1, 2, 3, 5, 10, 15, 20]`).
- **Ce face acum:** export sheet limitează slider la 10x, dar replay-ul nativ poate merge la 20x.
- **Ce trebuie:** alinează pe `speedSteps` (Picker cu valori discrete în loc de slider continuu).
- **Sursă audit:** [AUDIT_SWIFT § Lipsuri 17](AUDIT_SWIFT.md#lipsuriobservații)
- **Effort:** 0.1 zile.

### P0.10 — Cumulative cost chip ascuns când = 0

- **File:line:** `swift/Claude-MTW-Replay/Views/Chats/ChatView.swift:61` (`if vm.cumulativeCostUsd > 0`).
- **Ce face acum:** chip dispărut complet la primul prompt → user nu știe că featureul există.
- **Ce trebuie:** afișează chip-ul mereu, "$0.0000" la început, cu tooltip "Cumulative cost this chat session". Adaugă breakdown per turn (`vm.lastTurnCostUsd`) ca chip secundar.
- **Sursă audit:** [AUDIT_SWIFT § Lipsuri 11](AUDIT_SWIFT.md#lipsuriobservații)
- **Effort:** 0.2 zile.

**Total P0:** ~9.6 zile.

---

## P1 — Paritate cu web (features lipsă)

Pentru fiecare item din lista "Doar în Web" din [AUDIT_DIFF.md § Doar în Web](AUDIT_DIFF.md#doar-în-web-lipsă-în-swift), decidem dacă se portează.

### P1.1 — Import HTML Replay (`HTMLExtractor` UI)

- **Status:** API-ul există complet (`Services/HTMLExtractor.swift:13-198`); doar entrypoint UI lipsește.
- **Ce trebuie:** (a) menu item `File → Import HTML Replay…` (`Claude_MTW_ReplayApp.swift commands { ... }`) cu shortcut `Cmd+Shift+I`; (b) acțiune deschide `NSOpenPanel` filtrat la `.html`; (c) parse → `ExtractedData` → push în memory ca pseudo-sesiune și deschide tab Replay. Sesiunea importată **nu** se persistă pe disk (e ephemeral).
- **Sursă:** [AUDIT_DIFF Rec. 1](AUDIT_DIFF.md#recomandări-pentru-paritate-completă)
- **Effort:** 1 zi.

### P1.2 — Session chaining (multi-input concatenation)

- **Ce trebuie:** `Dashboard → multiselect rows → toolbar "Chain" button`. Apelează un nou helper `TranscriptParser.parseAndChain(filePaths:)` care: (a) parsează fiecare, (b) sortează cronologic după `firstTimestamp`, (c) reindexează `turn.index` global. Nu se salvează nimic — rezultatul deschide Replay/Editor temporar.
- **Sursă:** [AUDIT_DIFF § Doar în Web](AUDIT_DIFF.md#doar-în-web-lipsă-în-swift)
- **Effort:** 1.5 zile.

### P1.3 — Cross-project search (caut în cursor + codex, nu doar claude)

- **File:line:** `swift/Claude-MTW-Replay/Services/SearchService.swift:31-43`
- **Ce trebuie:** `searchAllProjects` să itereze peste `SessionDiscovery.discoverSessions(claudeAccountDir:)` cu toate cele 3 surse, nu doar `~/.claude*/projects/`.
- **Sursă:** [AUDIT_SWIFT § Search](AUDIT_SWIFT.md#funcționalități--search)
- **Effort:** 1 zi.

### P1.4 — `--theme-file` custom JSON themes

- **Ce trebuie:** (a) `ThemeService.loadThemeFile(_:)` deja există; (b) UI: Settings → secțiune "Custom Themes" cu listă + buton "Import…" + buton "Reload from disk"; (c) salvezi path-urile în UserDefaults, theme name = filename (fără ext). Theme picker existent în toolbar se actualizează automat.
- **Sursă:** [AUDIT_DIFF § Doar în Web](AUDIT_DIFF.md#doar-în-web-lipsă-în-swift)
- **Effort:** 1 zi.

### P1.5 — Bulk Include All / Exclude All în Editor

- **File:line:** `swift/Claude-MTW-Replay/Views/Editor/TurnBrowserPanel.swift:2-17`
- **Ce trebuie:** două butoane în toolbar `TurnBrowserPanel`: "Include All" (golește `excludedTurns`) și "Exclude All" (umple cu toți indecșii). Plus context-menu cu "Exclude before this", "Exclude after this".
- **Sursă:** [AUDIT_SWIFT § Editor "Lipsuri funcționale"](AUDIT_SWIFT.md#funcționalități--editor)
- **Effort:** 0.5 zile.

### P1.6 — Bookmark add UI în Replay (hotkey `B`)

- **File:line:** `swift/Claude-MTW-Replay/Views/Replay/ReplayView.swift` + `ReplayViewModel.swift`
- **Ce trebuie:** (a) `vm.addBookmark(at:label:)` care append la `bookmarks` + persistă în SwiftData (entitate nouă `BookmarkEntity` sau extensie `FavoriteEntity`); (b) `.onKeyPress("b")` în `ReplayView` care prompt-uiește label inline; (c) `BookmarkBarView` deja afișează cercurile.
- **Sursă:** [AUDIT_SWIFT § Lipsuri 9](AUDIT_SWIFT.md#lipsuriobservații), [AUDIT_DIFF Rec. 10](AUDIT_DIFF.md#recomandări-pentru-paritate-completă)
- **Effort:** 1 zi.

### P1.7 — Tool grouping threshold sincronizat

- **File:line:** `swift/Claude-MTW-Replay/Views/Replay/ReplayTurnView.swift:33-83` (Swift `≥5`) vs web (`≥1` toate consecutive).
- **Ce trebuie:** decizie de produs (recomandare: păstrăm `≥5` în Swift și migrăm web să folosească același prag — e mai prietenos vizual). Documentăm în CHANGELOG ca break-change. Făcută configurabilă: `UserDefaults("toolGroupThreshold")` default `5`.
- **Sursă:** [AUDIT_DIFF Rec. 6](AUDIT_DIFF.md#recomandări-pentru-paritate-completă)
- **Effort:** 0.5 zile.

### P1.8 — Session compare cu diff highlighting semantic

- **File:line:** `swift/Claude-MTW-Replay/Views/Dashboard/SessionCompareView.swift:8-30`
- **Ce trebuie:** (a) diff per turn cu `LCS` (Longest Common Subsequence) la nivel de userText + blocks (compare prin block kind + text similarity > 80% threshold); (b) highlight: identical = gri, added/removed = roșu/verde, modified = galben; (c) panel rezumat în header "X identical, Y modified, Z added".
- **Sursă:** [AUDIT_SWIFT § Lipsuri 6](AUDIT_SWIFT.md#lipsuriobservații)
- **Effort:** 2 zile.

### P1.9 — OG image default custom

- **File:line:** `swift/Claude-MTW-Replay/ViewModels/ExportViewModel.swift:93` — folosește `https://es617.github.io/claude-replay/og.png` (același hardcode ca web).
- **Ce trebuie:** opțional. (a) bundle un `og.png` local în `Resources/`, generăm un data-URI pentru self-contained; SAU (b) păstrăm URL extern și expunem un field în Settings "OG image URL" cu default.
- **Sursă:** [AUDIT_WEB § Lipsuri](AUDIT_WEB.md#lipsuriobservații), [AUDIT_DIFF § Doar în Web](AUDIT_DIFF.md#doar-în-web-lipsă-în-swift)
- **Effort:** 0.5 zile.

### P1.10 — Bookmarks `--mark "N:Label"` și `--bookmarks FILE` (echivalent UI)

- **Ce trebuie:** odată ce P1.6 e gata, expune un sheet `BookmarksEditorView` (View → Bookmarks…) cu listă editabilă + buton "Import JSON" + "Export JSON". Format compatibil cu CLI: `[{turn: 5, label: "First failure"}, ...]`.
- **Sursă:** [AUDIT_DIFF § Doar în Web](AUDIT_DIFF.md#doar-în-web-lipsă-în-swift)
- **Effort:** 0.5 zile.

### Items declarate Web-only intentional (nu se portează în Swift)

- **Terminal embedded (lazygit + xterm.js)** — specific deployment-ului server. Pe macOS native folosim NSWorkspace.openTerminal (deja există în `GitActionsView`).
- **Docker / docker-compose** — irelevant pentru app native.
- **CSRF privacy check** — irelevant (nu există server HTTP în Swift).
- **`POST /api/browse` HOME-restricted file browser** — Swift folosește `NSOpenPanel` standard care e mai bun din UX.
- **SSE `/api/events`** — echivalentul nostru e FileWatcher (P0.6).
- **npm CLI binary** — DMG e modelul nostru de distribuție.

**Total P1 portat:** ~9 zile.

---

## P2 — Code quality / Deduplicare

Probleme de cod care nu afectează direct utilizatorul dar sporesc riscul de drift și costul mentenanței.

### P2.1 — Single source of truth pentru secret patterns

- **File:line:** `swift/Claude-MTW-Replay/Models/SecretPattern.swift` (struct + 11 patterns) vs `swift/Claude-MTW-Replay/Services/SecretRedactor.swift` (enum + 11 patterns near-identice).
- **Ce trebuie:** păstrăm `Services/SecretRedactor.swift` ca single source (deja folosit de `HTMLRenderer.turnsToJsonData`), îl rescriem să expună `SecretRedactor.patterns: [SecretPattern]` și `SecretPattern` în `Models/`. Ștergem dublura. Adăugăm 17 teste unit portate din `test/test-secrets.mjs` (web).
- **Sursă:** [AUDIT_SWIFT § Lipsuri 13](AUDIT_SWIFT.md#lipsuriobservații)
- **Effort:** 0.5 zile.

### P2.2 — Single source pentru themes

- **File:line:** `Models/Theme.swift` (SwiftUI Colors) vs `Services/ThemeService.swift` (hex strings).
- **Ce trebuie:** singura sursă = un JSON resource bundlat `themes.json` cu cele 8 teme; la load creezi atât SwiftUI `Color` cât și CSS string dintr-un singur dict. `Theme` și `ThemeService` devin facade peste loader-ul JSON. Beneficiu: noi teme = doar JSON, nu Swift recompile.
- **Sursă:** [AUDIT_SWIFT § Lipsuri 14](AUDIT_SWIFT.md#lipsuriobservații)
- **Effort:** 1 zi.

### P2.3 — Eliminare sidecar duplicat

- **File:line:** `swift/sidecar/sidecar.js` (8.6 KB) vs `swift/Claude-MTW-Replay/Sidecar/sidecar.js` (8.6 KB, **identical** verificat cu `diff -q`).
- **Ce trebuie:** `build.sh` deja face copia; sursa rămâne **doar** `swift/sidecar/sidecar.js`. Trebuie să `git rm` copia din `Claude-MTW-Replay/Sidecar/sidecar.js` (rămâne `package.json` și `node_modules` ca artefacte ale build.sh) și să o adăugăm la `.gitignore`. Pre-build script va eșua dacă lipsește sursa.
- **Sursă:** [AUDIT_SWIFT § Sidecar](AUDIT_SWIFT.md#sidecar-node--sidecarsidecarjs)
- **Effort:** 0.5 zile.

### P2.4 — `AnyCodable` wrapper simplificare

- **File:line:** `Models/Turn.swift` (definiție `AnyCodable`) folosit doar pentru `ToolCall.input: [String: AnyCodable]`.
- **Ce trebuie:** evaluează înlocuirea cu `JSONValue` enum (idiom mai modern): `enum JSONValue { case null, bool(Bool), number(Double), string(String), array([JSONValue]), object([String: JSONValue]) }`. Beneficii: `Equatable`/`Hashable` automat, encoding/decoding mai puține surprize, type-safety mai bun.
- **Effort:** 1 zi.

### P2.5 — `@preconcurrency import WebKit` în ExportViewModel

- **File:line:** `swift/Claude-MTW-Replay/ViewModels/ExportViewModel.swift:4`
- **Ce trebuie:** este OK pe termen scurt (Apple va updata anotările). Documentează cu comentariu de ce; verifică la fiecare Xcode major dacă mai e necesar.
- **Sursă:** [AUDIT_SWIFT § Lipsuri 15](AUDIT_SWIFT.md#lipsuriobservații)
- **Effort:** 0.1 zile (doar comment).

### P2.6 — `Color.toHex()` nullable când e dinamic

- **File:line:** `swift/Claude-MTW-Replay/Extensions/Color+Theme.swift:3-23` folosit de `ExportViewModel.renderOptions:88` cu fallback `?? "#1a1b26"`.
- **Ce trebuie:** garantezi că temele built-in nu folosesc system colors (ele sunt definite hex explicit deja); add `precondition` în debug că `theme.bg.toHex() != nil` pentru cele 8 teme.
- **Sursă:** [AUDIT_SWIFT § Lipsuri 12](AUDIT_SWIFT.md#lipsuriobservații)
- **Effort:** 0.2 zile.

### P2.7 — Combine import nefolosit

- **File:line:** `swift/Claude-MTW-Replay/ViewModels/ReplayViewModel.swift` (audit menționează `import Combine` fără consumer).
- **Ce trebuie:** elimină importul mort.
- **Effort:** 0.1 zile.

**Total P2:** ~3.4 zile.

---

## P3 — Polish UX

Lucruri care fac diferența între un app "merge" și un app "îmi place".

### P3.1 — Drag-drop session files pe window (nu doar pe icon)

- **Ce trebuie:** `WindowGroup` `.onDrop(of: [.fileURL]) { ... }` care filtrează `.jsonl` și forwardează la `AppState.selectSession(...)`. Visual feedback (overlay translucid "Drop JSONL here").
- **Effort:** 1 zi.

### P3.2 — Recent sessions menu (File → Open Recent)

- **Ce trebuie:** standard `NSDocumentController.shared.recentDocumentURLs` + persistare în UserDefaults. Append automat la fiecare `appState.selectSession(path:)`. Submeniu în File menu cu max 10 + "Clear Menu".
- **Effort:** 0.5 zile.

### P3.3 — Autosave editor state

- **File:line:** `swift/Claude-MTW-Replay/ViewModels/EditorViewModel.swift`
- **Ce trebuie:** când user editează `workingTurns`, debounce 2s → serialize `[excludedTurns, edits]` în `UserDefaults("editor-state-<sessionPath>")`. La reload (`.task(id:)`) restore. Buton explicit "Discard" în toolbar.
- **Effort:** 1.5 zile.

### P3.4 — Accessibility VoiceOver

- **Ce trebuie:** audit `Color`-only states (status chips, error indicators), adaugă `.accessibilityLabel(_:)` peste tot unde labelStyle e iconOnly. Spinner verb cu `.accessibilityHidden(true)`. Replay autoscroll cu `.accessibilityAnnouncement` la nou turn.
- **Effort:** 2 zile.

### P3.5 — Keyboard navigation complete

- **Ce trebuie:** Tab navigation prin Project list / Session table / Replay controls. `↑/↓` în sidebar = navigare proiecte; `Enter` = activare. Editor `↑/↓` între turns. Documentat în `KeyboardShortcutsView`.
- **Effort:** 1.5 zile.

### P3.6 — Splash / Empty-state cu Lottie animations

- **Ce trebuie:** când no session selected, afișează un empty state cu Lottie subtle (sau SF Symbol cu animație). Brand consistent. Mascot deja există.
- **Effort:** 0.5 zile.

### P3.7 — SpinnerVerb reflect status (nu doar decorativ)

- **File:line:** `swift/Claude-MTW-Replay/Models/SpinnerVerbs.swift` (195 verbe) folosit de toolbar.
- **Ce trebuie:** sub-listare per stare: "Loading…" (Resolving / Parsing / Indexing), "Chatting…" (Composing / Tooling / Thinking). În chat live, verbe trase din `vm.status` enum.
- **Sursă:** [AUDIT_SWIFT § Lipsuri 10](AUDIT_SWIFT.md#lipsuriobservații)
- **Effort:** 1 zi.

### P3.8 — Smooth scroll + cursor blink în Chat

- **Ce trebuie:** transcript chat scroll cu `withAnimation(.spring(response: 0.4, dampingFraction: 0.85))`. Adăugă un caret blink la sfârșitul ultimului text block când `status == .sending`.
- **Effort:** 0.5 zile.

### P3.9 — Dashboard heatmap interactiv

- **File:line:** `Views/Dashboard/ActivityHeatmapView.swift`
- **Ce trebuie:** hover pe celulă → tooltip cu data + count sesiuni. Click → filtrează `SessionTableView` la acea zi.
- **Effort:** 1 zi.

**Total P3:** ~9.5 zile.

---

## Chat tab — Plan de excelență

Aceasta este secțiunea-cheie: Chat-ul e flagship-ul Swift și trebuie să-l ridicăm la standardul unui client production-ready (Cursor Chat / Claude.ai desktop).

### Status actual

Cel mai detaliat audit e în [AUDIT_SWIFT § Chats](AUDIT_SWIFT.md#funcționalități--chats-chat-interactiv). Reț in:

- ✅ **Chat live cu streaming** prin sidecar Node + `@anthropic-ai/claude-agent-sdk@0.1.5`.
- ✅ **Status chips:** idle / starting / ready / sending / error.
- ✅ **Resume from session** prin `ChatSessionListView` (per-proiect).
- ✅ **Permission modes:** Plan / Accept Edits / Default (bypass ascuns deliberat).
- ✅ **Prefix chips:** `@` (file pick + inline content max 64KB), `!` (shell command + inline output max 16KB), `#` (memory directive).
- ✅ **Verbose toggle** (Ctrl+R) → respawn cu `--partial-messages`.
- ✅ **Cost tracking:** `lastTurnCostUsd` + `cumulativeCostUsd` din eventul `result.total_cost_usd`.
- ✅ **Optimistic user turn** + reconcile cu echo SDK.
- ✅ **Tool result folding** prin `tool_use_id`.
- ✅ **Stop button** (Esc) cu graceful stop → terminate fallback 1s.
- ✅ **Account-aware** (Plan/AcceptEdits modes; bypassPermissions opt-in).

### Gap-uri vs un client production-ready

Aici e zona unde trebuie cea mai multă muncă. Toate punctele de mai jos sunt **gap-uri** vs un client modern.

#### G1 — Persistență istoric chat local

- **Problemă:** orice chat e ephemeral; la close fereastră, `vm.turns` (tot ce a venit de la SDK post-resume) **se pierde**. Singura urmă rămâne fișierul JSONL pe care SDK-ul îl actualizează în background, dar nu există vizibilitate explicită că "chat-ul a fost salvat".
- **Soluție:** entitate SwiftData nouă `ChatTranscriptEntity(sessionPath, projectPath, turnsJSON, accountDir, lastUpdated, costUsd, model)` + index per `sessionPath`. La fiecare `apply(msg:)` cu deltas, persistăm. UI: `ChatsView` afișează lista "Active Chats" (chat-uri cu activitate în ultimele 7 zile) ca quick-resume.
- **Effort:** 3 zile.

#### G2 — Conversation forking / branching

- **Problemă:** când vrei să "te întorci 5 turn-uri și să modifici", nu există cale.
- **Soluție:** în `ChatView`, fiecare turn user are un menu contextual `... → Branch from here`. Action: (a) duplică sesiunea (copiază JSONL la `<id>-branch-<timestamp>.jsonl` truncat la N turns), (b) deschide o instanță nouă `ChatView` cu nouă session ID, (c) păstrează legătura în SwiftData ca `parentSessionId`. UI ulterior afișează `ChatTreeView` cu graf de branches.
- **Effort:** 4 zile (M + 1 ulterior pentru tree visualization).

#### G3 — MCP servers integration UI

- **Problemă:** `claude-agent-sdk` v0.1.5+ suportă MCP server config (`mcpServers: {...}` în options); sidecar-ul nostru nu expune asta.
- **Soluție:** (a) Settings → "MCP Servers" tab cu listă `[{name, command, args, env}]` persistat în UserDefaults; (b) `ClaudeAgent.StartOptions` adaugă `mcpServers: [MCPServerSpec]`; (c) sidecar.js le forwardează în `options.mcpServers`; (d) ChatView header arată badge "MCP: 3 servers" + click pentru detalii. Toolbox suplimentar disponibil în slash-commands.
- **Effort:** 4 zile.

#### G4 — Model picker (Sonnet 4.6 / Opus 4.7 / Haiku 4.5) cu cost preview

- **Problemă:** nu există `--model` flag în sidecar; SDK folosește default-ul user-ului.
- **Soluție:** (a) `ClaudeAgent.StartOptions.model: String?`; (b) sidecar.js push `options.model = args.model` dacă specificat; (c) UI: dropdown deasupra textbox-ului cu opțiunile + per-million-token pricing afișat. La switch model, **respawn agent** (același pattern ca permissionMode).
- **Effort:** 1 zi.

#### G5 — System prompt editing per-conversation

- **Problemă:** nu poți customiza system prompt-ul fără să umbli în CLAUDE.md global.
- **Soluție:** (a) buton "System Prompt" în header `ChatView`; (b) sheet editor cu textarea + checkbox "Include CLAUDE.md", "Include MEMORY.md"; (c) save → respawn cu `--system-prompt-append <text>` (SDK suportă `customSystemPrompt`); (d) persistă per-sessionPath în SwiftData.
- **Effort:** 2 zile.

#### G6 — Tool whitelisting/blacklisting UI

- **Problemă:** `allowedTools` există ca property pe `ChatViewModel` dar UI nu o expune.
- **Soluție:** menu "Tools" în header chat cu listă: `Bash, Read, Edit, Write, Glob, Grep, WebFetch, WebSearch, NotebookEdit, TodoWrite, Task` (plus MCP tools auto-detected) + toggle per tool. Salvează în SwiftData per-session.
- **Effort:** 1.5 zile.

#### G7 — Slash commands integration

- **Problemă:** Claude Code TUI suportă `/commands` din `.claude/commands/*.md`. Swift Chat n-are.
- **Soluție:** (a) când user tasteaza `/`, scanezi `<projectPath>/.claude/commands/*.md` + `~/.claude/commands/*.md` + listezi ca dropdown cu autocompletion; (b) la pick, înlocuiește `/cmd` cu conținutul fișierului ca prompt expanded; (c) `argsSupport` (`$ARGUMENTS` placeholder).
- **Effort:** 2 zile.

#### G8 — Permission management UI (per-tool, per-session, persistent)

- **Problemă:** modurile actuale sunt globale; nu poți spune "approve Bash, prompt for Write".
- **Soluție:** (a) când SDK emite event `permission_request`, sidecar îl forwardează la Swift; (b) Swift afișează modal "Allow Bash to run `ls -la`?" cu butoane: Once / Always / Never; (c) persistă deciziile per `(sessionId, toolName, action_signature)` în SwiftData.
- **Effort:** 3 zile (necesită SDK suport).

#### G9 — File picker drag-drop direct în chat input

- **Problemă:** `@` deschide NSOpenPanel; drag-drop direct nu funcționează.
- **Soluție:** `ChatInputBarView` adaugă `.onDrop(of: [.fileURL])` → pentru fiecare URL, inline content ca code fence (max 64KB per file, max 5 files concomitent). Visual feedback (drop zone highlight).
- **Effort:** 1 zi.

#### G10 — Attachment preview (imagini, PDF, code) inline

- **Problemă:** dacă inlinezi un PDF sau imagine, e doar text; nu există preview.
- **Soluție:** detect MIME (image/* → `AsyncImage` inline; PDF → thumbnail + click sheet `QLPreviewView`; code → `CodeBlockView` cu syntax highlight). SDK acceptă `image_url` blocks; folosim.
- **Effort:** 2 zile.

#### G11 — Streaming render quality (cursor blink, smooth scroll, chunk batching)

- **Problemă:** scroll-ul "sare" la fiecare bloc nou; nu există indicator vizual de "scriere în desfășurare" la nivel de text block (doar la nivel de "Claude is composing…" în footer).
- **Soluție:** (a) caret blink (`▌`) la sfârșitul ultimului `AssistantTextView` în modul `sending`; (b) chunk batching: nu re-render markdown la fiecare delta, ci la fiecare ~50ms sau la `\n`; (c) scroll smooth cu `withAnimation(.spring())`.
- **Effort:** 1.5 zile.

#### G12 — Token usage live counter

- **Problemă:** cost cumulativ există, dar nu vezi tokens.
- **Soluție:** parse `result.usage` din SDK event (`input_tokens`, `output_tokens`, `cache_creation_tokens`, `cache_read_tokens`) → afișează 4 chip-uri în header chat. Tooltip cu pricing actual per model.
- **Effort:** 1 zi.

#### G13 — Stop / regenerate la mijlocul răspunsului

- **Problemă:** "Stop" există (Esc); "Regenerate" nu.
- **Soluție:** la sfârșitul unui turn assistant, hover → buton "Regenerate". Action: șterge last turn assistant, păstrează last user, respawn agent cu prompt `<re-send user message>`. Necesită ca SDK să accepte "edit-last-and-resend" (alternativ, manual: agent.stop → spawn nou cu `--resume <sid>` care va relua de la commitul anterior).
- **Effort:** 2 zile.

#### G14 — Export chat la HTML/PDF/Markdown

- **Problemă:** `ExportSheet` lucrează pe transcript replay; chat live n-are entrypoint.
- **Soluție:** `ChatView` header → menu "Export" → reuse `ExportViewModel.export(turns: vm.turns, options: ...)`. Turns sunt deja Turn objects, deci pipeline-ul existent funcționează 1:1.
- **Effort:** 0.5 zile.

#### G15 — Resume chat dintr-un session JSONL existent (legare Replay ↔ Chats)

- **Problemă:** workflow-ul de tipic "watch replay → continue" e fragmentat. Acum: deschizi Replay tab, alegi sesiune, dar nu există shortcut "Continue this chat".
- **Soluție:** `ReplayControlsView` adaugă buton "Continue (live)" care `appState.switchTab(.chats)` + setează `resumingPath = currentSessionPath`. Bonus: din `SessionTableView` → buton "Resume" deja duplicat existent să fie consistent.
- **Effort:** 0.5 zile.

#### G16 — Multi-tab chats (mai multe conversații simultan)

- **Problemă:** doar o conversație la momentul T per fereastră.
- **Soluție:** `ChatsView` devine un `TabView` orizontal cu chat-uri active. Fiecare tab are propriul `ChatViewModel` (deja per-instanță). State persistat în SwiftData (G1). Close-tab vs close-chat diferit.
- **Effort:** 2 zile (după G1).

### Sidecar improvements

- **Două copii identice (`swift/sidecar/sidecar.js` și `swift/Claude-MTW-Replay/Sidecar/sidecar.js`)** — `diff -q` confirmă identitate. **Acțiune:** vezi P2.3 — păstrăm doar sursa, copy generat de `build.sh`, `.gitignore` adaugat la destinație.
- **Error handling robustness:** azi orice `fatal()` din sidecar trimite `{type:"error"}` și `exit(1)`. Suficient. Lipsește: (a) timeout pentru `await import("@anthropic-ai/claude-agent-sdk")` — dacă SDK e corupt npm install poate hang-ui; (b) heartbeat ping din sidecar (1/30s) ca Swift să detecteze sidecar zombie.
- **IPC protocol versioning:** azi protocolul e implicit (`{type:"ready"}`, etc.). Adaugă `{"type":"hello","protocol":"1"}` ca prim mesaj; Swift validează și refuză versiuni necunoscute. Permite evoluție viitoare.
- **Sandboxing:** sidecar rulează cu env-ul user-ului (`ProcessInfo.processInfo.environment`). Pe macOS, considerăm activarea Hardened Runtime cu entitlements explicite (deja activă, dar XPC isolation ar fi un upgrade — `XPC service` cu interface contract).
- **Logging:** azi stderr e drenat ca "error event". Mai bine: structurăm log levels (`{level:"debug|info|warn|error", msg:...}`); UI Settings → "Show sidecar logs" pentru debugging.
- **Effort total sidecar:** 2 zile.

### Account integration cu chat

- Multi-account funcționează la nivel de listare; **chat-ul** rulează cu env-ul user-ului indiferent de account selectat.
- **Soluție necesară:** când user e pe `claude-yahoo`, sidecar trebuie spawn-uit cu `CLAUDE_CONFIG_DIR=$HOME/.claude-yahoo` (sau echivalent — SDK respectă această env var). Validăm:
  1. `ChatViewModel.start()` să preia `appState.claudeAccountDir` și să-l pase la `StartOptions`.
  2. `ClaudeAgent.start()` setează `env["CLAUDE_CONFIG_DIR"] = expandedAccountDirPath`.
  3. Test: deschide chat în account A, apoi în account B → costurile, history-ul, MCP-urile trebuie să fie izolate.
- **Cross-account conversation move:** v2 — nu acum.
- **Effort:** 1 zi.

### Roadmap Chat

Milestones de mărimea unui sprint (2 săptămâni).

- **CM1 — Foundations & UX polish** (1 sprint, ~10 zile)
  - G1 (persistență istoric) — 3z
  - G14 (export chat) — 0.5z
  - G15 (Replay ↔ Chats link) — 0.5z
  - G11 (streaming polish) — 1.5z
  - G12 (token counter) — 1z
  - P0.5 (split-view) sau G16 (multi-tab) — 3z
  - Account integration cu chat (env var) — 1z

- **CM2 — Power features** (1 sprint, ~10 zile)
  - G4 (model picker) — 1z
  - G5 (system prompt) — 2z
  - G6 (tool whitelisting) — 1.5z
  - G7 (slash commands) — 2z
  - G9 (drag-drop) — 1z
  - G10 (attachment preview) — 2z
  - Sidecar protocol versioning + heartbeat — 1z

- **CM3 — Advanced** (1 sprint, ~10 zile)
  - G2 (conversation forking) — 4z
  - G8 (permission management UI) — 3z
  - G13 (regenerate) — 2z
  - QA + bug bash — 1z

- **CM4 — MCP & ecosystem** (1 sprint, ~10 zile)
  - G3 (MCP servers integration) — 4z
  - Stretch: voice input (Whisper local) — 3z
  - Stretch: code execution preview (run Bash output în WKWebView inline) — 2z
  - Polish & ship — 1z

**Total Chat:** ~40 zile-om pentru a aduce Chats la nivel "production-ready competitive cu Cursor/Claude.ai desktop". Plus 8 zile sidecar/integration.

---

## Testing strategy

### Unit tests

Coverage actual: 2 fișiere, ~150 linii ([AUDIT_SWIFT § Testare](AUDIT_SWIFT.md#testare)). Țintă: 250+ teste pentru paritate cu web.

- **`TranscriptParser` (prioritate maximă):** portează `test/test-parser.mjs` (46 `it`) ca XCTest. Fixture-urile JSONL din `test/fixture*.jsonl` se copiază în `swift/Claude-MTW-Replay/Tests/Fixtures/` și `Bundle.module.url(forResource:)`. Effort: 3 zile.
- **`SecretRedactor`:** portează `test/test-secrets.mjs` (17). Effort: 0.5 zile.
- **`ThemeService`:** portează `test/test-themes.mjs` (6). Effort: 0.5 zile.
- **`StatsComputer`:** test pentru fiecare metric (turnCount, blockCounts, toolBreakdown, files, agents, duration, charCounts). Effort: 1 zi.
- **`HTMLRenderer` round-trip cu `HTMLExtractor`:** render → extract → asertează equal turns + bookmarks. Effort: 0.5 zile.
- **`MarkdownExporter`:** snapshot tests pentru turns cu fiecare block kind. Effort: 0.5 zile.
- **`SessionResolver` / `SessionDiscovery`:** mock `~/.claude*` cu `FileManager.default.temporaryDirectory`; test exact match, partial UUID match Codex. Effort: 1 zi.
- **Total unit:** ~7 zile.

### Integration tests

- **Sidecar IPC:** extinde `ClaudeAgentSkeletonTests` (`Tests/ClaudeAgentSkeletonTests.swift`). Adaugă teste pentru: spawn failure, stop graceful, stop forceful, stdin write after stop, multiple sends concurrent. Effort: 1 zi.
- **SwiftData persistence:** spin un `ModelContainer(inMemory: true)` în test, CRUD favorites + tags + meta, asertează indecșii + invalidation pe mtime. Effort: 1 zi.
- **FileWatcher events:** test cu tmpdir, scrii fișier, asertează `.created`; rename, asertează `.modified`; delete, asertează `.deleted`. Effort: 1 zi.
- **Total integration:** ~3 zile.

### UI tests (XCUITest)

- **Flow Open project → Select session → Play replay:** `xcuiapp.cells["claude-myproject"].click()` → `xcuiapp.tables["sessions"].cells.firstMatch.buttons["Replay"].click()` → asertează play button state. Effort: 1.5 zile.
- **Flow Edit turn → Export HTML:** open editor → edit textarea → exclude turn → export → asertează fișier scris. Effort: 1 zi.
- **Flow Chat resume:** mock sidecar (skeleton mode), trimite mesaj, asertează echo în UI. Effort: 1 zi.
- **Total UI:** ~3.5 zile.

### Sidecar tests

- **Mock claude-agent-sdk pentru a permite snapshot tests fără API calls reale:** creează `swift/sidecar/test/mock-sdk.js` care exportă `query()` care emite events pre-recorded dintr-un fixture JSON. `package.json` adaugă `test` script cu `node --test`. Effort: 1.5 zile.
- **Total sidecar:** ~1.5 zile.

**Total testing strategy:** ~15 zile-om.

---

## Sincronizare versiuni

### Status curent (problema)

| Component | Versiune | Sursă |
|---|---|---|
| `Info.plist:33` | `1.0` / build `1` | hardcoded |
| `project.yml:59-60` | `MARKETING_VERSION=1.0.0`, `CURRENT_PROJECT_VERSION=1` | source-of-truth Swift |
| Root `package.json:3` | `0.8.1` | source-of-truth web |
| DMG livrat | `Claude-MTW-Replay-0.8.1.dmg` | `scripts/build-dmg.sh:22` citește root `package.json` |
| Sidecar `swift/sidecar/package.json:3` | `0.8.0` | uitat la ultim update |

### Decizie recomandată

1. **Alegere source-of-truth pentru Swift:** `project.yml` MARKETING_VERSION.
2. **`build-dmg.sh:22`** să citească din `project.yml` (`yq` sau grep+sed): `VERSION=$(grep MARKETING_VERSION swift/project.yml | awk -F'"' '{print $2}')`.
3. **Sincronizează sidecar:** `swift/sidecar/package.json:3` → același number ca Swift app (ex. `1.0.0`).
4. **CHANGELOG dedicat Swift:** `swift/CHANGELOG.md` nou, separat de `CHANGELOG.md` web. Format Keep-a-Changelog. Reia versiunile 0.8.0 (chat tab) și 0.8.1 (web parity) ca puncte istorice.
5. **Marketing version pentru release public:** decizie de produs: rămânem la 1.0 (pre-release feel) sau bumpăm la 0.8.1 (potrivit cu pipeline-ul web). Recomandare: **1.0.0 pentru primul release Mac App Store / public DMG**; reseteaza CHANGELOG-ul ca "1.0.0 — first public release".

### Effort

- Update `build-dmg.sh` + verify: 0.3 zile.
- Sync sidecar version + npm publish (dacă cazul): 0.2 zile.
- Scrie CHANGELOG Swift: 0.5 zile.
- **Total:** 1 zi.

---

## Distribuție / Release engineering

Toate punctele blochează un release "real" către utilizatori non-dev.

### RE1 — Code signing real (înlocuim ad-hoc `"-"`)

- **Curent:** `project.yml:64 CODE_SIGN_IDENTITY: "-"` (ad-hoc). Utilizatorii primesc Gatekeeper warning la prima rulare.
- **Acțiune:** înrolare Apple Developer Program ($99/an), generare Developer ID Application cert, config în `project.yml`:
  ```yaml
  CODE_SIGN_IDENTITY: "Developer ID Application: <Name> (TEAMID)"
  DEVELOPMENT_TEAM: TEAMID
  ```
- **Effort:** 1 zi (inclusiv setup CI signing).

### RE2 — Notarization Apple

- **Acțiune:** post-build, rulează `xcrun notarytool submit ... --wait`, apoi `xcrun stapler staple`. Integrare în `build-dmg.sh`. Necesită App-specific password în keychain CI.
- **Effort:** 1 zi.

### RE3 — Auto-update cu Sparkle

- **Acțiune:** integrare `Sparkle` (cocoapods / SPM), generează `appcast.xml` la fiecare release, host pe `https://es617.github.io/claude-mtw-replay/appcast.xml`. EdDSA signing key în keychain.
- **Effort:** 2 zile.

### RE4 — Universal binary verification

- **Curent:** xcodebuild produce universal implicit (arm64 + x86_64) deja.
- **Acțiune:** adaugă în CI `lipo -info Claude-MTW-Replay.app/Contents/MacOS/Claude-MTW-Replay` să verifice "arm64 x86_64". Smoke test pe Rosetta.
- **Effort:** 0.5 zile.

### RE5 — Crash reporting

- **Acțiune:** integrare `Sentry` (`sentry-cocoa` SPM) cu `dsn` în Info.plist via xcconfig. Symbol upload script în post-build. Alternativ folosim MetricKit + custom backend (mai puțin overhead, mai puțin standard).
- **Effort:** 1.5 zile.

### RE6 — Telemetry minimă (opt-in)

- **Acțiune:** Settings → checkbox "Send anonymous usage stats" (default OFF). Events min: `app_launched`, `tab_switched`, `chat_started`, `export_clicked`. PostHog sau Plausible. Documentează privacy policy.
- **Effort:** 1 zi.

### RE7 — Mac App Store pipeline

- **Acțiune (opțional):** dacă vrem MAS distribuție, sandboxing strict (app sandbox + entitlements minimal); ce necesită refactor: shell command (`/bin/sh -c`) în Chat input nu va fi posibil sub sandbox. Decizie: păstrăm distribuție directă DMG pentru power-users.
- **Effort:** N/A (decizie strategică).

**Total RE:** ~6–8 zile.

---

## Roadmap propus

Sprint = 2 săptămâni (10 zile-om).

### Sprint 1 — Stop the bleeding (P0)

Țintă: aplicația nu mai are nicio buton-mort sau stub vizibil.

- P0.1 Favorites real listing (1z)
- P0.2 Tags listing + assign (2z)
- P0.3 ExportSheet button wired (0.5z)
- P0.4 MenuBar real status item (2z)
- P0.6 FileWatcher wired (1.5z)
- P0.7 KeyboardShortcuts fix (0.2z)
- P0.8 Settings sidecar locator (0.5z)
- P0.9 Speed slider fix (0.1z)
- P0.10 Cost chip always visible (0.2z)
- Buffer: 2z

### Sprint 2 — Web parity (P1)

- P1.1 Import HTML (1z)
- P1.2 Session chaining (1.5z)
- P1.3 Cross-project search (1z)
- P1.4 Custom themes (1z)
- P1.5 Bulk Include/Exclude (0.5z)
- P1.6 Bookmark add (1z)
- P1.7 Tool grouping threshold (0.5z)
- P1.9 OG default (0.5z)
- P1.10 Bookmarks editor (0.5z)
- P0.5 Split-view chat (3z)

### Sprint 3 — Code quality + Testing foundation

- P2.1–P2.7 deduplicare (3.4z)
- Unit tests: Parser + Redaction + Themes + Stats (5z)
- P1.8 Session compare diff (2z)

### Sprint 4 — Chat Excellence M1 (Foundations)

- Vezi `Roadmap Chat → CM1` (10z): persistență, polish, multi-tab, account integration.

### Sprint 5 — Chat Excellence M2 (Power features)

- Vezi `Roadmap Chat → CM2` (10z): model picker, system prompt, tool whitelisting, slash commands, attachments.

### Sprint 6 — Chat Excellence M3 + Release engineering

- Chat M3 (forking, permission UI, regenerate): 9z
- Versioning sync (1z)
- Signing + Notarization (2z)
- Sparkle (2z)
- Crash + telemetry (2.5z) — split next sprint dacă overflow

### (Optional) Sprint 7 — Chat M4 (MCP) + UI polish

- G3 MCP integration (4z)
- P3 polish items (5z)
- Final QA + 1.0 launch (1z)

**Total roadmap:** 6–7 sprint-uri (12–14 săptămâni / 60–84 zile-om).

---

## Out of scope (proiecte separate)

Nu fac parte din acest plan, dar merită menționate ca direcții posibile.

- **iOS / iPadOS port** — SwiftUI codul ar putea fi reutilizat (~70%) dar Chats live cu sidecar Node nu rulează pe iOS. Soluție: server remote SDK proxy.
- **Linux port** — alternativă: GTK + Vala sau o variantă Tauri-based ce reutilizează template-ul web. Sau Catalyst (macOS-only oricum).
- **Cloud sync conversations** — sync `ChatTranscriptEntity` între device-uri via CloudKit. Necesită Apple Developer setup + container CloudKit.
- **Multi-user collaboration** — două persoane în același chat (operational transform pe `inputDraft`). Complexitate: necesită backend.
- **Browser extension** — Open Replay Direct din pagini Claude.ai. Manifest V3 + native messaging.
- **Plugin ecosystem (Claude Code style)** — `.claude-mtw-replay/plugins/*.swift` runtime loadable (interpreter sau JIT). Foarte ambitios.
- **Vector search semantic** — index transcripte cu embeddings (Apple `NaturalLanguage` framework + ANN). În loc de substring search.
- **AI-powered summarization** — la deschidere a unei sesiuni cu >100 turns, generează un TL;DR via SDK.
- **Time travel debugging** — replay cu breakpoints semantice ("pause when X tool fails").

---

## Referințe și apendix

- [AUDIT_SWIFT.md](AUDIT_SWIFT.md) — auditul Swift (606 linii), sursă canonică pentru toate file:line.
- [AUDIT_WEB.md](AUDIT_WEB.md) — auditul web (455 linii), folosit ca referință de paritate.
- [AUDIT_DIFF.md](AUDIT_DIFF.md) — diferențe + recomandări (215 linii).
- Codul Swift: `/Users/anonymous-dd/work/claude-replay/swift/Claude-MTW-Replay/`
- Sidecar: `/Users/anonymous-dd/work/claude-replay/swift/sidecar/sidecar.js` (canonic) + copia auto-generată `/Users/anonymous-dd/work/claude-replay/swift/Claude-MTW-Replay/Sidecar/sidecar.js`.
- Build script: `/Users/anonymous-dd/work/claude-replay/swift/scripts/build-dmg.sh`.
