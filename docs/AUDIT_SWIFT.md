# Audit aplicație Swift — Claude-MTW-Replay

Aplicație macOS nativă, SwiftUI-first, care servește ca alternativă completă la frontend-ul web `claude-replay`: descoperă, parsează, redă, editează, exportă și (nou în v0.8.x-swift) **continuă live** sesiuni Claude Code / Cursor / Codex CLI. Codul live de chat este conectat la un sidecar Node bundlat în .app care wraps `@anthropic-ai/claude-agent-sdk`.

---

## Versiune și metadate

- `CFBundleShortVersionString` = **1.0**, `CFBundleVersion` = **1** — `swift/Claude-MTW-Replay/Info.plist:33`.
- `MARKETING_VERSION = "1.0.0"`, `CURRENT_PROJECT_VERSION = "1"` în `swift/project.yml:59-60`.
- Versiunea efectivă livrată (folosită de `build-dmg.sh`) e luată din rădăcina repo-ului `package.json` → `0.8.1` (`swift/scripts/build-dmg.sh:22`, `package.json:3`).
- Sidecar Node bundlat: `name: claude-mtw-replay-sidecar`, `version: 0.8.0` — `swift/sidecar/package.json:3`.
- Deployment target macOS: **15.0** declarat în `project.yml:5,13`; `LSMinimumSystemVersion: "14.0"` în `project.yml:78` (rulează pe macOS 14+, build target 15).
- Swift: **5.9**, Xcode: **16.0**, concurrency mode: `SWIFT_STRICT_CONCURRENCY: complete` — `project.yml:12-15`.
- Bundle ID: `com.claude-replay.Claude-MTW-Replay`; Product name: `Claude MTW Replay`; Category: `public.app-category.developer-tools` — `project.yml:52-57`.
- Hardened Runtime enabled, ad-hoc code sign (`CODE_SIGN_IDENTITY: "-"`) — `project.yml:63-65`.
- DMG-uri prezente: `swift/dist/Claude-MTW-Replay-0.8.0.dmg`, `swift/dist/Claude-MTW-Replay-0.8.1.dmg`.
- Ultimul commit relevant pentru Swift: `54e566e feat: add claude-yahoo account support`; lanțul recent include `v0.8.1-swift: web parity` (`b66fc89`) și `v0.8.0-swift: interactive Chats tab via @anthropic-ai/claude-agent-sdk` (`ca916b2`).

---

## Arhitectură generală

- Stack: **SwiftUI + MVVM strict**, observabilitate prin `@Observable` (macros, fără `ObservableObject`), persistență **SwiftData** (NU CoreData).
- Layout cod în `swift/Claude-MTW-Replay/`:
  - `App/` — entrypoint + state global (`AppState`, `AppDelegate`)
  - `Models/` — value types pure (12 fișiere)
  - `Persistence/` — `DataStore` + 4 `@Model` entități SwiftData
  - `Services/` — 14 servicii utilitare statice / actor
  - `ViewModels/` — 10 `@Observable` ViewModel-uri
  - `Views/` — împărțit pe sub-feature (Dashboard, Chats, Replay, Editor, Transcript, Stats, Git, Search, Export, Sidebar, Shared)
  - `Extensions/`, `Resources/`, `Tests/`, `Sidecar/` (Node bundlat)
- Flux utilizator → UI:
  - `Views` citesc `AppState` via `@Environment(AppState.self)` și un `@State` ViewModel local
  - `ViewModel` invocă un `Service` (parser, discovery, git, agent…) → returnează value types
  - Pentru chat live: `ChatViewModel` deține un `ClaudeAgent` actor care fork-uie procesul `node sidecar.js` și consumă un `AsyncThrowingStream<StreamEvent>` peste stdin/stdout JSONL line-protocol.
- Tot ce e UI rulează `@MainActor`-isolated; parsing-ul JSONL e dispatched pe `Task.detached(priority: .utility)` (`SessionListViewModel.enrichIfNeeded`).
- Pasarea stării e exclusiv prin `AppState` (`@Observable`) + Bindings; **nu** se folosește `EnvironmentObject`.

---

## Entry points / Lifecycle

- `swift/Claude-MTW-Replay/App/Claude_MTW_ReplayApp.swift:3-44` — punctul `@main`.
  - Adapter `@NSApplicationDelegateAdaptor(AppDelegate.self)`.
  - `WindowGroup { ContentView() }` cu `minWidth: 900`, `minHeight: 600`, default `1200×800`.
  - `Settings { SettingsView() }` — fereastra standard de Preferences macOS.
  - `commands { ... }`:
    - Suprimă `newItem` (nu există document creation).
    - Menu propriu **Navigate** cu `Cmd+1..7` mapate la `AppTab.allCases`, plus `Cmd+F` (search) și `Cmd+E` (export).
    - `Help → Keyboard Shortcuts` (`Cmd+/`).
  - `?` global deschide sheet-ul `KeyboardShortcutsView`.
- `App/AppDelegate.swift:8-14` — handler `application(_:open:)`: filtrează URL-uri `.jsonl` și emite `Notification.didReceiveDroppedSession` (drag-and-drop pe icon / "Open With").
- `App/AppState.swift`:
  - `enum AppTab { dashboard, chats, replay, transcript, editor, stats, git }` — 7 taburi (`AppState.swift:3-23`).
  - `@Observable class AppState` ține: `currentTab`, `selectedProjectDirName`/`selectedProjectSource`/`selectedProject`, `selectedSessionPath`, `selectedThemeName`, `claudeAccountDir`, sheet-uri (`showExportSheet`, `showSearchSheet`, `showKeyboardShortcuts`), `favoritesVM` și `sidebarSelection`.
  - Metode: `selectProject`, `selectSession` (auto-switch la `.replay`), `switchTab`, `setClaudeAccount`.
  - `struct ClaudeAccount` + `enum AccountStore` — descoperă `~/.claude` și `~/.claude-<name>` dir-uri cu `projects/` (multi-cont) (`AppState.swift:81-133`).
- Nu există menu bar extra (NSStatusItem); directorul `Views/MenuBar/` e prezent dar **gol** (vezi `Lipsuri/observații`).

---

## Ecrane / Tab-uri

Layout-ul global: `NavigationSplitView { SidebarView() } detail: { MainTabBarView() + switch on currentTab }` cu sheet-uri pentru Export, Search, Shortcuts (`Views/ContentView.swift:8-54`).

| Tab | Scop | Fișiere principale |
|---|---|---|
| **Dashboard** | Project overview + tabela de sesiuni + sub-tab-uri (Stats / Plans / CLAUDE.md / MEMORY.md) | `Views/Dashboard/DashboardView.swift`, `SessionTableView.swift`, `SessionRowView.swift`, `ProjectHeaderView.swift`, `ActivityHeatmapView.swift`, `PlansListView.swift`, `ProjectFilesView.swift`, `SessionCompareView.swift` |
| **Chats** | Continuare live a unei sesiuni prin SDK | `Views/Chats/ChatsView.swift`, `ChatView.swift`, `ChatSessionListView.swift`, `ChatInputBarView.swift`, `ModeToggleView.swift` |
| **Replay** | Player nativ animat al transcript-ului | `Views/Replay/ReplayView.swift`, `ReplayControlsView.swift`, `ReplayTurnView.swift`, `UserMessageView.swift`, `AssistantTextView.swift`, `ThinkingBlockView.swift`, `ToolCallView.swift`, `BookmarkBarView.swift` |
| **Transcript** | Vizualizare statică, full, cu filtre + search | `Views/Transcript/TranscriptView.swift`, `TranscriptTurnView.swift`, `TranscriptSearchBar.swift`, `TranscriptFilterBar.swift` |
| **Editor** | Editor de transcript: exclude turns, edit user text, prep export | `Views/Editor/EditorView.swift`, `TurnBrowserPanel.swift`, `TurnEditorPanel.swift` |
| **Stats** | Metrici, tool breakdown, files, agents | `Views/Stats/StatsView.swift`, `StatsOverviewCards.swift`, `ToolBreakdownChart.swift`, `BashCommandsListView.swift`, `FilesAccessedView.swift`, `AgentsListView.swift` |
| **Git** | Info repo: branch, status, log, graph + Open in Finder/Terminal | `Views/Git/GitView.swift`, `GitInfoView.swift`, `CommitLogView.swift`, `GitGraphView.swift`, `GitActionsView.swift` |

Sheet-uri globale (peste tab-ul curent):
- **Export** — `Views/Export/ExportSheet.swift`, `ExportProgressView.swift`.
- **Global Search** — `Views/Search/GlobalSearchView.swift`, `SearchResultRowView.swift`.
- **Keyboard Shortcuts** — `Views/Shared/KeyboardShortcutsView.swift`.

Sidebar:
- `Views/Sidebar/SidebarView.swift` — listă proiecte grupate pe sursă (claude/cursor/codex) cu searchable + sort modes + AccountSwitcher + Refresh.
- `Views/Sidebar/ProjectRowView.swift`, `FavoritesSectionView.swift`, `TagsSectionView.swift` (ultimele două sunt stub-uri "No favorites yet"/"No tags yet").

MenuBar: directorul `Views/MenuBar/` **este gol** — nu există NSStatusItem implementat.

---

## Funcționalități — Chats (chat interactiv)

**Da, există LLM chat live cu streaming.** Implementat în două straturi:

### Strat Swift (`ChatViewModel` + `ClaudeAgent` actor)
- `ChatViewModel` (`ViewModels/ChatViewModel.swift:14-293`):
  - Status enum: `idle / starting / ready / sending / error(String)`.
  - Pe `start()`: seed-uiește `turns` cu transcript-ul existent (via `TranscriptParser.parseTranscript`) → spawn-uiește sidecar-ul → consumă `AsyncThrowingStream<StreamEvent>` și foldează în UI.
  - `send(_:)` — append optimistic + scrie pe stdin sidecar.
  - `cancel()` — Esc → `agent.stop()`.
  - `changeMode(_:)` / `setVerbose(_:)` — schimbarea acestor flag-uri **respawnează** sidecar-ul (SDK aplică `permissionMode` doar la session start).
  - Tracking cost: `lastTurnCostUsd` + `cumulativeCostUsd` din evenimentul `result.total_cost_usd`.
- `ClaudeAgent` actor (`Services/ClaudeAgent.swift:17-227`):
  - Owner-ul procesului `node sidecar.js`. API: `start(options)` → `AsyncThrowingStream<StreamEvent, Error>`, `send(_:)`, `stop()`.
  - Wire protocol: line-delimited JSON pe stdin (`{"type":"send","text":...}` / `{"type":"stop"}`) și stdout (`ready`, `agent_event`, `error`, `exit`).
  - Stderr e drenat pe un `Task.detached` separat ca să nu blocheze copilul.
  - Stop graceful: scrie `stop` → așteaptă 1s → `terminate()` → `cancel()` pe readerTask.

### Strat Node sidecar (`Sidecar/sidecar.js`)
- Vezi secțiunea dedicată mai jos. Wrappează `query()` din `@anthropic-ai/claude-agent-sdk` peste un async generator alimentat de stdin.

### UI Chat
- `ChatsView` (`Views/Chats/ChatsView.swift`): empty state dacă nu e proiect selectat; altfel `ChatSessionListView`.
- `ChatSessionListView` (`Views/Chats/ChatSessionListView.swift:12-108`): listează sesiunile proiectului cu trei butoane per rând — **Transcript** (sheet cu `TranscriptView`), **Resume** (sheet cu `ChatView`), **Split** (disabled — deferred la v0.8.1).
- `ChatView` (`Views/Chats/ChatView.swift:17-143`):
  - Header: nume sesiune + path + status chip + cost cumulativ + Close.
  - Status chips: Idle / Connecting… / Ready (•) / Streaming… / Error.
  - Transcript: `LazyVStack(ForEach turns) { TranscriptTurnView(turn: ) }` cu autoscroll la `vm.turns.last?.id` și indicator "Claude is composing…".
- `ChatInputBarView` (`Views/Chats/ChatInputBarView.swift:14-224`):
  - `TextEditor` multi-linie, send via `Cmd+Return`; Stop button (`buttonStyle(.borderedProminent).tint(.red)`) cu shortcut `Esc` în timpul `sending`.
  - **Prefix chips** (parity cu TUI Claude Code):
    - `@` — deschide `NSOpenPanel`, inline-uiește conținutul fișierului (max 64KB) ca code fence.
    - `!` — sheet de input pentru shell command → rulează `/bin/sh -c` în `vm.projectPath`, inlinează combined stdout/stderr (max 16KB).
    - `#` — adaugă literal `#` în draft pentru directive memory.
  - Toggle Verbose (`Ctrl+R`) → respawnează sidecar cu `--partial-messages`.
- `ModeToggleView` (`Views/Chats/ModeToggleView.swift:10-48`): trei chips — **Plan** (read-only), **Accept Edits** (auto-approve), **Default** (prompt). `bypassPermissions` deliberat ascuns din UI.

### Account picker
- `claude-yahoo` / `claude-outlook` / orice `~/.claude-*` cu `projects/` apar automat în `AccountSwitcherMenu` (descoperite de `AccountStore.availableAccounts()` în `AppState.swift:109-133`).
- Switch-ul afectează doar listarea (`SessionDiscovery.discoverProjects(claudeAccountDir:)`) — nu impactează direct sidecar-ul (acela rulează cu CWD-ul proiectului și moștenește env-ul user-ului via `Process.environment`).

---

## Funcționalități — Dashboard

`DashboardView` (`Views/Dashboard/DashboardView.swift:3-67`):
- Conține `ProjectHeaderView` cu nume, path, "X sessions", last/first activity, Finder/Terminal launchers, și **`ActivityHeatmapView`** (GitHub-style ~26 săptămâni × 7 zile colorat pe accent — `Views/Dashboard/ActivityHeatmapView.swift:8-91`).
- `Picker(.segmented)` cu 5 sub-tab-uri: **Sessions** / **Stats** / **Plans** / **CLAUDE.md** / **MEMORY.md**.

`SessionTableView` (`Views/Dashboard/SessionTableView.swift:11-140`):
- Coloane: SESSION (cu star/fav) · PREVIEW · DATE · DURATION · TURNS · SIZE · ACTIONS (Replay / Transcript / Edit / MD) · toggle Compare.
- Headerele DATE/DURATION/TURNS/SIZE sunt sortable (click pentru toggle asc/desc).
- Mod Compare: selecție de exact 2 sesiuni → deschide `SessionCompareView` sheet (side-by-side prin `HSplitView` cu `TranscriptTurnView` per pane — **fără** diff highlighting, marcat ca deferred în `SessionCompareView.swift:9`).

`SessionListViewModel` (`ViewModels/SessionListViewModel.swift:11-100`):
- Sortare pe `date/duration/turns/size` (asc/desc) — `SessionSortKey`.
- Filtering pe `searchText` (caut în `sessionId` și `preview`).
- `compareSelection: Set<String>` (cap la 2 — FIFO).
- `enrichIfNeeded(_:)` — lazy enrichment: pentru fiecare rând care apare în viewport, dacă `preview == nil`, lansează un `Task.detached(.utility)` care apelează `SessionMetaService.meta(for:)` (parsare JSONL completă pentru preview + turn count + duration). Tracking via `enriching: Set<String>` ca să nu se dubleze parsele.

Sub-tab-ul **Plans** (`Views/Dashboard/PlansListView.swift:9-117`):
- Listează `~/.claude/plans/<encoded-dir>/*.md` (encoded dir = path-ul proiectului cu `/` → `-`).
- `HSplitView` cu listă selectabilă (sortare descrescătoare după mtime) → preview cu `MarkdownTextView`.
- Fallback la `~/.claude/plans/` flat pentru install-uri vechi.

Sub-tab-uri **CLAUDE.md / MEMORY.md** (`Views/Dashboard/ProjectFilesView.swift:2-26`):
- Citesc `<projectPath>/CLAUDE.md` (rezolvat prin `SessionDiscovery.claudeDirToProjectPath`) și `~/.claude/projects/<dir>/memory/MEMORY.md`.
- Render prin `MarkdownTextView`.

Favorites:
- `FavoritesViewModel` (`ViewModels/FavoritesViewModel.swift:3-37`) — `loadFavorites/isFavorite/addFavorite/removeFavorite/toggle` peste `DataStore.shared`.
- `SessionRowView.sessionIdCell` — star icon clickable, toggle prin `appState.favoritesVM.toggle(...)` (`Views/Dashboard/SessionRowView.swift:38-63`).
- `Views/Sidebar/FavoritesSectionView.swift:2-9` este însă un **stub** ("No favorites yet" hard-coded) — nu listează favorite-ele reale.

Tags: `TagEntity` și `DataStore` au CRUD complet (`Persistence/DataStore.swift:99-141`) dar UI-ul `TagsSectionView.swift:2-8` e stub similar; doar `TagChipView` (`Views/Shared/TagChipView.swift`) e un component reutilizabil — nu e wired în table.

---

## Funcționalități — Editor

`EditorView` (`Views/Editor/EditorView.swift`) — `HSplitView` cu `TurnBrowserPanel` (left, minWidth 200) și `TurnEditorPanel` (right, minWidth 300).

`EditorViewModel` (`ViewModels/EditorViewModel.swift:3-49`):
- `originalTurns: [Turn]` snapshot inițial + `workingTurns: [Turn]` editabil + `excludedTurns: Set<Int>` + `bookmarks: [Bookmark]`.
- `hasEdits` derivat din diferențele față de original.
- `editTurnText(index:newText:)`, `toggleExclude(index:)`, `reset()`.
- `prepareTurnsForExport()` — filtrează turns excluse și re-indexează pentru export.

`TurnBrowserPanel` (`Views/Editor/TurnBrowserPanel.swift:2-17`):
- `List(selection:)` cu Toggle per turn (bifa = inclus, debifa = exclus).
- Afișează `Turn N` + preview user text (lineLimit 2).

`TurnEditorPanel` (`Views/Editor/TurnEditorPanel.swift:2-22`):
- `TextEditor` legat la `workingTurns[idx].userText`.
- Counter "Blocks: N", "Modified" indicator dacă `hasEdits`.
- Buton Reset.

**Lipsuri funcționale** declarate în spec dar **neimplementate** în UI:
- Bulk select multi-turn (`Cmd+Click`) — nu există.
- Redaction config UI — `redactSecrets` e `Bool` în `ExportOptions` cu default `true`, dar nu se expune un toggle în Editor; redactarea se aplică automat la export.
- Theme picker per session în Editor — nu există; folosește global `appState.theme`.
- Salvarea de bookmark-uri manuale — nu există acțiune pentru append la `bookmarks` din UI Editor.

---

## Funcționalități — Replay

`ReplayView` (`Views/Replay/ReplayView.swift:2-87`):
- `LazyVStack(ForEach turns) { ReplayTurnView(...) }` cu `opacity 0.25` pentru turnurile nerevelate încă (animație `easeInOut(0.4)`).
- Autoscroll la `vm.currentTurnIndex` prin `ScrollViewReader`.
- `revealedBlocks(for:)` calculează câte blocuri sunt vizibile per turn.

`ReplayViewModel` (`ViewModels/ReplayViewModel.swift:5-136`):
- Stare: `turns`, `currentTurnIndex`, `revealedBlockCount`, `isPlaying`, `speed`, `showThinking`, `showToolCalls`, `bookmarks`.
- `speedSteps: [0.5, 1, 2, 3, 5, 10, 15, 20]`.
- `play()` — `Task @MainActor` async loop care revelează bloc cu bloc cu `adaptiveDelay`: `min(max(charCount * 0.03, 0.6), 10.0) / speed` secunde per bloc; 0.5s pauză între turnuri.
- `togglePlay/pause/stepForward/stepBack/nextTurn/prevTurn/seekToTurn`.

`ReplayControlsView` (`Views/Replay/ReplayControlsView.swift:2-35`):
- Progress bar clickabil pentru seek (`onTapGesture { location in vm.seekToTurn(...) }`).
- Backward / Play-Pause / Forward + `Text("Turn X/Y")` + Speed Picker + Toggle Thinking + Toggle Tools.

Keyboard shortcuts (`ReplayView.swift:11-27`):
- `Space` / `K` — toggle play
- `→` / `L` — step forward bloc
- `←` / `H` — step back bloc
- `Shift+→` / `L` (capital) — next turn complet
- `Shift+←` / `H` (capital) — prev turn complet
- `T` — toggle thinking
- `Esc` — pause

`ReplayTurnView` (`Views/Replay/ReplayTurnView.swift:2-83`):
- Antet "Turn N" + timestamp.
- `UserMessageView`.
- Tool grouping inteligent: secvențe de ≥5 `toolUse` blocks consecutive se colapsează în `CollapsedToolGroupView` (DisclosureGroup cu summary "X tool calls (names)") — `ReplayTurnView.swift:33-83`.
- Per bloc: `AssistantTextView` (Markdown via `MarkdownTextView`), `ThinkingBlockView` (DisclosureGroup gri), `ToolCallView`.

`ToolCallView` (`Views/Replay/ToolCallView.swift:2-40`):
- DisclosureGroup. Header: cerc colorat (red dacă isError, blue altfel) + nume tool + preview (command pentru Bash, file_path pentru Read/Write/Edit, pattern pentru Grep).
- Pentru Bash: `CodeBlockView` cu syntax highlighting bash.
- Pentru Edit: `DiffView(oldText, newText, filePath)` (diff side-by-side cu add/del/context).
- Rezultatul: text monospaced, `green` la success, `red` la error.

`BookmarkBarView` (`Views/Replay/BookmarkBarView.swift:2-16`): cercuri colorate pe progress bar pentru fiecare bookmark, click → `seekToTurn`.

Deep link: `AppDelegate.application(_:open:)` postează `Notification.didReceiveDroppedSession` pentru `.jsonl`-uri drag-dropped pe icon (`App/AppDelegate.swift:9-13`) — declarația tipului de document `JSONL Transcript` în `Info.plist:8-21`.

Splash nativ: nu există o "splash screen" dedicată; există însă `SpinnerVerbView` în toolbar (verb cycling + shimmer reverse-sweep).

---

## Funcționalități — Stats

`StatsView` (`Views/Stats/StatsView.swift:2-24`) cu `StatsViewModel` (`ViewModels/StatsViewModel.swift:3-15`) care apelează `StatsComputer.compute(turns:)`.

Metrici calculate de `StatsComputer` (`Services/StatsComputer.swift:3-99`):
- `turnCount`, `blockCounts.{text, thinking, toolUse}`, `errorCount`.
- `toolBreakdown: [String: Int]` — cazuri per nume tool.
- `bashCommands: [BashCommand]` — comanda + turnIndex + isError.
- `filesRead`, `filesEdited` — extrași din Read/Edit/Write `file_path` (deduplicate via Set).
- `agents: [AgentInfo]` — sub-agents (tool name == "Agent"): name, model, prompt (200 char), mode.
- `duration: TimeInterval?` — diff între prima și ultima timestamp (turn + block + tool result).
- `charCounts.{user, assistant, thinking}`, `avgBlocksPerTurn`, `longestTurn`.
- `userMessages`, `assistantTexts` — preview-uri (200 char) pentru cele 2 categorii.

Vizualizări:
- `StatsOverviewCards` (`Views/Stats/StatsOverviewCards.swift`) — 4 carduri grid: Turns / Duration / Errors / Tools Used.
- `ToolBreakdownChart` (`Views/Stats/ToolBreakdownChart.swift`) — **Swift Charts** (`import Charts`) `BarMark` orizontal cu paletă temă-aware.
- `BashCommandsListView`, `FilesAccessedView`, `AgentsListView` — listare + indicator de eroare.

---

## Funcționalități — Git integration

`GitService` (`Services/GitService.swift:22-66`) — wrappere peste `/usr/bin/git`:
- `getGitInfo(projectPath:)` — `rev-parse --abbrev-ref HEAD`, `remote`, `status --porcelain` → count `modified/added/deleted`.
- `getGitDetails(projectPath:)` — `rev-list --count HEAD`, `log --oneline --format=%H%x1f%s%x1f%an%x1f%ad --date=relative -30` parsed prin Unit Separator (`\u{1f}`), `log --graph --oneline --all -50`.

UI:
- `GitView` (`Views/Git/GitView.swift:2-22`) — un singur ScrollView cu InfoView + CommitLogView + GitGraphView + GitActionsView.
- `GitInfoView` (`Views/Git/GitInfoView.swift`) — Branch / Status (clean sau XM YA ZD) / Remotes.
- `CommitLogView` (`Views/Git/CommitLogView.swift`) — primele 30 commit-uri: hash (8 char) + message + author + relative date.
- `GitGraphView` (`Views/Git/GitGraphView.swift`) — `--graph` output în text monospaced, scroll vertical (max 300pt).
- `GitActionsView` (`Views/Git/GitActionsView.swift`) — **Open in Finder** (`NSWorkspace.selectFile`) și **Open in Terminal** (AppleScript spre `Terminal.app`).

**Nu există**: diff, blame, branch operations, fetch/pull/push — Git tab e read-only summary.

---

## Funcționalități — Search

`SearchService` (`Services/SearchService.swift:3-44`):
- `search(query:in projectDirName:maxFiles:30,maxResults:50)` — listează JSONL-urile (sort descendent) din `~/.claude/projects/<dir>`, parsează cu `TranscriptParser.parseTranscriptFromText`, scanează user text (cu strip `<system-reminder>`) și fiecare bloc, returnează `SearchResult` (project + path + turnIndex + matchText prefix 200 + role + context).
- `searchAllProjects(query:maxResults:claudeAccountDir:)` — iterează peste toate proiectele descoperite și concatenează.
- Match-uire: **case-insensitive substring** (lowercased `contains`). Nu există regex / fuzzy / scope filtru explicit; `claude-only` (nu caută în cursor/codex).

`GlobalSearchView` (`Views/Search/GlobalSearchView.swift:2-41`):
- Triggered de `Cmd+F` (sheet).
- Dacă există proiect selectat → scope la proiectul curent; altfel search global.
- Rulat pe `Task.detached`; rezultatele se apasă pentru a sări la sesiune (`appState.selectSession(...)` → tab `.replay`).
- `SearchResultRowView` — Turn N · role chip · matchText preview.

---

## Funcționalități — Export

`ExportSheet` (`Views/Export/ExportSheet.swift:2-22`) — formular: format (HTML/Markdown/PDF), `ThemePickerView`, slider Speed (0.5–10). **Butonul Export are însă un `/* TODO */` în body — pare să fie incomplet wired din sheet** (vezi Lipsuri/observații).

`ExportViewModel` (`ViewModels/ExportViewModel.swift:7-144`):
- `enum ExportFormat { html, markdown, pdf }`.
- `export(turns:options:)` dispatch după format:
  - **HTML** — `NSSavePanel` (`.html`) → `HTMLRenderer.render(turns:options:)` → scrie la URL.
  - **Markdown** — `NSSavePanel` (`.md`) → `MarkdownExporter.turnsToMarkdown(turns:title:)`.
  - **PDF** — `NSSavePanel` (`.pdf`) → renderează HTML într-un `WKWebView` offscreen → `webView.pdf(configuration: WKPDFConfiguration())`.

`HTMLRenderer` (`Services/HTMLRenderer.swift:24-195`):
- Încarcă `Resources/player.min.html` (fallback `player.html`) — același template HTML player ca web-ul.
- Înlocuiește placeholders `/*THEME_CSS*/`, `/*THEME_BG*/`, `/*INITIAL_SPEED*/`, `/*CHECKED_THINKING*/`, `/*CHECKED_TOOLS*/`, `/*PAGE_TITLE*/`, `/*PAGE_DESCRIPTION*/`, `/*OG_IMAGE*/`, `/*USER_LABEL*/`, `/*ASSISTANT_LABEL*/`, `/*BOOKMARKS_DATA*/`, `/*TURNS_DATA*/`.
- Compresie embedată: `compressForEmbed(_:)` → raw deflate (RFC 1951) compatibil cu `zlib.deflateSync()` din Node → base64. Strip-uiește header zlib (`0x78 0x9C`) și Adler-32 (4 ultimii bytes).
- Sau `escapeJsonForScript` (mod `--no-compress`) — JS string literal escaping.
- `turnsToJsonData(_:redact:)` — serializare slimă a Turn-urilor cu redaction opțională peste tot (user text, blocks, tool input recursiv, tool result).

`MarkdownExporter` (`Services/MarkdownExporter.swift:5-123`):
- Output: `# Title`, `---`, `## Turn N — timestamp UTC`, `### User`, `### Assistant`, code fences pentru Bash, `**File:**` + diff fence pentru Edit, `\`\`\`json` pentru tool generic, `**Result:**` sau `**Error:**` blocks.
- Suportă `<details><summary>Thinking</summary>` collapsible.

`ExportOptions` (`Models/ExportOptions.swift`):
- theme, speed, showThinking, showToolCalls, userLabel, assistantLabel, title, description, ogImage, redactSecrets (default `true`), bookmarks, minified, compress, `TimingOptions` (pauseBeforeAssistant=500, charMultiplier=30, minDuration=1000, maxDuration=10000).

`HTMLExtractor` (`Services/HTMLExtractor.swift:13-198`):
- Reverse-operație: parsează un HTML player generat, extrage cele 2 blobs (turns + bookmarks), decomprimă (`COMPRESSION_ZLIB` cu fallback raw-deflate cu zlib header sintetic), decode JSON → `ExtractedData`. Util pentru round-trip / re-import.

---

## Funcționalități — MenuBar

**Directorul `Views/MenuBar/` este gol** (verificat cu `ls`). Aplicația nu implementează un NSStatusItem / menu bar extra. Toate quick actions sunt în:
- Toolbar-ul ferestrei principale (`ContentView.swift:28-49`): Theme quick toggle (sun/moon), Theme menu, Search button, Help button.
- Navbar `CommandMenu("Navigate")` (`Claude_MTW_ReplayApp.swift:22-32`).

Spinner-ul (`SpinnerVerbView` în `ToolbarItem(placement: .principal)`) folosește lista de **187 verbe** din `Models/SpinnerVerbs.swift` cu cycle 2.4s și shimmer reverse-sweep gradient.

---

## Parser și formate suportate

`TranscriptParser` (`Services/TranscriptParser.swift:16-847`) — port complet (1:1 funcțional) al `parser.mjs` din versiunea web:

Formate suportate (`Models/TranscriptFormat.swift`):
- **Claude Code** (`claude-code`) — detected by `type == "user"` sau `type == "assistant"` la nivel top.
- **Cursor** (`cursor`) — detected by `role == "user"|"assistant"` în obiectele fără `type` top-level; conține `{ role, message: { content }, timestamp }`. Format normalizat la shape Claude Code.
- **Codex** (`codex`) — detected by `type == "session_meta"` în primul line; folosește un model event-based diferit (`event_msg`/`response_item` cu `task_started`/`task_complete`).
- **Unknown** — fallback dacă nimic nu match-uiește.

Funcționalități parser:
1. `cleanSystemTags(_:)` — strip-uiește `<task-notification>`, `<system-reminder>`, `<ide_opened_file>`, `<local-command-caveat>`, `<local-command-stdout>`, `<user_query>`, `<command-message>`, etc. Înlocuiește `<task-notification>` cu `[bg-task: summary]` marker (păstrat ulterior ca `systemEvents`).
2. `extractText(_:)` — handle pentru string content sau array de blocks (filtrează doar `type:"text"`).
3. `detectFormatFromText(_:)` — peek pe primul JSON line.
4. `parseJsonl(_:)` — line-by-line, normalizează Cursor la shape Claude Code.
5. `collectAssistantBlocks(_:start:)` — colectează `text/thinking/tool_use` consecutive, deduplicate pe `text:<content>` / `thinking:<content>` / `tool_use:<id>` keys.
6. `attachToolResults(_:entries:resultStart:)` — match `tool_result` blocks din user entries la `tool_use` prin `tool_use_id`; strip `<tool_use_error>` wrapper.
7. `parseCodexPatch(_:)` — parser pentru formatul Codex `*** Begin Patch / Add File / Update File / @@`; produce `Edit`/`Write`-style input dict.
8. `extractCodexUserText(_:)` — strip-uiește boilerplate IDE Codex, păstrează ce e după `## My request for Codex:`.
9. `parseCodexTranscript(_:)` — parser event-based dedicat Codex CLI: `task_started → user_message → response_item (message/function_call/custom_tool_call) → task_complete`. Mapează:
   - `exec_command` → `Bash` (combine `cwd` + `cmd`)
   - `apply_patch` → `Write` (dacă isNew) sau `Edit`
   - Tool results din `function_call_output` / `custom_tool_call_output`.
10. `parseTranscript(filePath:)` / `parseTranscriptFromText(_:)` — entry point.
11. `applyPacedTiming(_:)` — opțional, înlocuiește timestamp-urile cu pacing sintetic (500ms pauză + `min(max(len*30, 1000), 10000)` ms per bloc).
12. `filterTurns(_:options:)` — filtrare după `turnRange`, `excludeTurns`, `timeFrom`, `timeTo`.

Cursor edge case (`parseTranscript ...:680-691`): toate blocurile asistent în afară de ultimul per turn sunt re-clasificate `text → thinking`.

`Turn` model (`Models/Turn.swift`):
- `Turn { id, index, userText, blocks, timestamp, systemEvents }`.
- `AssistantBlock { id, kind: BlockKind, text, toolCall, timestamp }`.
- `ToolCall { id, toolUseId, name, input: [String: AnyCodable], result, resultTimestamp, isError }`.
- `BlockKind { text, thinking, toolUse }`.
- `AnyCodable` — type-erased Codable wrapper pentru tool input heterogen (Bool/Int/Double/String/Array/Dict/Null).

`StreamEvent` (live chat) — model SEPARAT, `Models/StreamEvent.swift:12-236`:
- `ready / echo / agentMessage(AgentMessage) / error / exit / unknown`.
- `AgentMessage`: `systemInit / userMessage / assistantMessage / streamDelta / result / other`.
- `AssistantContentBlock`: `text / thinking / toolUse(id,name,input)`.
- Decode forgiving — orice nu match-uie cade în `.unknown` / `.other` (wire format evoluabil).

---

## Session discovery & resolver

`SessionDiscovery` (`Services/SessionDiscovery.swift:74-429`) — port direct din `editor-server.mjs`:
- **`claudeDirToProjectPath(_:)`** — invers la encoding-ul Claude Code: dir name `-Users-joe-my-project` → `/Users/joe/my-project`. Algoritm greedy: încearcă să unească dash-separated parts și verifică existența pe FS pentru segmente intermediare; ultimul segment se acceptă necondiționat.
- **`discoverSessions(claudeAccountDir:)`** — returnează `[SessionGroup]` cu trei grupe: Claude Code (label dinamic: `Claude Code` sau `Claude Code (<account>)`), Cursor, Codex CLI.
- **`discoverProjects(claudeAccountDir:)`** — `[ProjectEntry]` sortat descendent după `lastActivity`.
- **`getProjectDetails(source:dirName:claudeAccountDir:)`** — pentru `source == "claude"`: detalii complete + CLAUDE.md (citit din `realPath`) + MEMORY.md (citit din `~/.claude/projects/<dir>/memory/MEMORY.md`).

Paths scanate (`Extensions/FileManager+Sessions.swift:16-23`):
- Claude Code: `~/<accountDir>/projects/*/<id>.jsonl` (accountDir = `.claude` sau orice `.claude-*` cu `projects/`).
- Cursor: `~/.cursor/projects/*/agent-transcripts/<id>/{transcript,<id>}.jsonl`.
- Codex CLI: `~/.codex/sessions/<YYYY>/<MM>/<DD>/*.jsonl`.

`SessionResolver` (`Services/SessionResolver.swift:15-147`):
- `resolve(sessionId:home:)` — given un session ID (cu sau fără `.jsonl`), scanează toate cele 3 root-uri pentru match-uri exacte și (Codex) match-uri parțiale UUID din pattern `rollout-YYYY-MM-DDTHH-MM-SS-<uuid>.jsonl`.
- `displayName(from:)` — derivă un nume scurt din dir-ul Claude/Cursor: ultimele 2 segmente dash-separated.

`FileWatcher` (`Services/FileWatcher.swift:6-185`):
- Wrapper peste `DispatchSourceFileSystemObject` (mask `.write/.delete/.rename/.extend`).
- Pentru directoare: diff `lastKnownContents` la fiecare event → emit `.created`/`.deleted`/`.modified`.
- Auto-restart 0.5s după `.delete`/`.rename`.
- `FileWatcher.watchSessionDirectories(handler:)` — convenience: watch toate 3 root-urile + fiecare subdir de proiect (pentru a detecta și fișiere noi în proiecte existente, nu doar proiecte noi).
- **Nu este folosit** explicit la nivel de UI/ViewModel — utilitate disponibilă, neconectată la `ProjectListViewModel` sau `SessionListViewModel` (ar trebui declanșat manual prin butonul Refresh).

---

## Persistență

**SwiftData**, NU CoreData. `Persistence/DataStore.swift:6-142`:
- Singleton `DataStore.shared` @MainActor.
- `ModelContainer` cu schema 4 entități și config `"ClaudeReplay"` (persistent on disk).
- API CRUD pentru meta cache, stats cache, favorites, tags.

Entități:
- **`SessionMetaEntity`** (`Persistence/SessionMetaEntity.swift:6-72`) — unique pe `path`. Atribute: projectDir, sessionId, fileMtime, fileSize, turnCount, duration, preview, userPreviewsJSON (Data), firstTimestamp, lastTimestamp, cachedAt. Lookup: `getCachedMeta(path:mtime:)` invalidează cache-ul automat când mtime se schimbă (predicate match pe ambele).
- **`SessionStatsEntity`** (`Persistence/SessionStatsEntity.swift:6-44`) — unique pe `path`. Salvează `SessionStats` full ca JSON blob (`statsJSON: Data`) cu mtime invalidation.
- **`FavoriteEntity`** (`Persistence/FavoriteEntity.swift:6-28`) — unique pe `path`. Câmpuri: sessionId, preview, projectDir, pinnedAt. Sort default după `pinnedAt` descendent.
- **`TagEntity`** (`Persistence/TagEntity.swift:6-22`) — composite unique pe `(path, tag)`. Câmpuri: path, tag, createdAt.

UserDefaults (settings rapid, non-SwiftData):
- `defaultTheme`, `defaultSpeed`, `showThinkingByDefault`, `showToolCallsByDefault`, `autoRedactSecrets` (`Views/Shared/SettingsView.swift:3-7`).
- `claudeAccountDir` (`AppState.swift:97`).
- `projectSortMode` (`ViewModels/ProjectListViewModel.swift:40`).
- `sidecarLocator.node` și `sidecarLocator.claude` (`Services/SidecarLocator.swift:78-79`).

---

## Redaction / Secrets

Două implementări paralele (overlap):

`Models/SecretPattern.swift` (struct + 11 patterns built-in):
- `redactAll(_:)` aplică toate patterns: private_key, aws_key, sk_ant_key, sk_key, key_prefix, bearer, jwt, connection_string, key_value, env_var, hex_token.

`Services/SecretRedactor.swift` (`enum` cu 11 patterns near-identice, plus `redactObject(_:)` care e recursive deep-walk pe orice `Any`):
- Folosit de `HTMLRenderer.turnsToJsonData(_:redact:)` (`Services/HTMLRenderer.swift:125-178`) pentru redact recursiv în tool input (vital — secret-uri pot apărea în Bash commands sau Write content).

`Extensions/String+Redaction.swift:5-23`:
- `String.redacted()` — sugar pentru `SecretRedactor.redactSecrets(self)`.
- `countOccurrences(of:)` — case-insensitive substring count (folosit de TranscriptViewModel pentru match count).

Toggle UI:
- `ExportOptions.redactSecrets: Bool` (default `true`).
- `SettingsView` are toggle global `autoRedactSecrets`.
- **Nu există** un UI per-secret-rule (ex. "doar AWS keys") — toate cele 11 se aplică în bloc.

---

## Teme

Două servicii: unul pentru UI nativ SwiftUI, unul pentru HTML export.

`Models/Theme.swift` (`Theme` struct cu Color SwiftUI + `ThemeName` enum):
- 8 teme built-in: `claudeDark, claudeLight, tokyoNight, monokai, solarizedDark, githubLight, dracula, bubbles`.
- Câmpuri colour: bg, bgSurface, bgHover, text, textDim, textBright, accent, accentDim, green, blue, orange, red, cyan, border, toolBg, thinkingBg, **extraCss**.
- `isDark` derivat (false pentru githubLight/bubbles/claudeLight).
- `Theme.bubbles.extraCss` conține CSS specific pentru estetică de chat-bubble (folosit doar la export HTML).

`Services/ThemeService.swift:209-277` (paralel, pentru HTML CSS):
- `getTheme(_:)`, `listThemes()`, `getAllThemes()`, `loadThemeFile(_:)` (din JSON custom path), `themeToCss(_:)` — emite `:root { --bg: ...; --accent: ...; }` + extraCss.

`Extensions/Color+Theme.swift:3-23`:
- `Color(hex:)` parser (3/6/8 hex digits) și `toHex() -> String?` round-trip via NSColor sRGB.

UI:
- `AppState.selectedThemeName: String` (UserDefaults `defaultTheme`).
- `ThemeToolbarMenu` (`Views/Shared/ThemeToolbarMenu.swift`) — Menu cu toate `ThemeName.allCases` cu checkmark.
- `ThemeQuickToggle` (același fișier) — sun/moon flip între `claude-dark` și `claude-light`.
- `Theme.named(_:)` — lookup string → struct.
- `appState.theme: Theme` — derived; toate view-urile citesc `appState.theme.{bg, accent, ...}`.

---

## Sidecar Node — `Sidecar/sidecar.js`

Există DOUĂ copii identice ale codului:
- `swift/sidecar/sidecar.js` — source de dezvoltare (cu `package-lock.json`, `README.md`, `build.sh`).
- `swift/Claude-MTW-Replay/Sidecar/sidecar.js` — copiat aici de `build.sh` și inclus în `.app/Contents/Resources/Sidecar/` de post-build script (`project.yml:34-49`).

Funcționalitate (`swift/Claude-MTW-Replay/Sidecar/sidecar.js:1-208`):
- Două moduri controlate prin argv:
  - `--skeleton` — echo mode pentru test plumbing (folosit de tests).
  - **Real agent mode** (default): apelează `query()` din `@anthropic-ai/claude-agent-sdk` (importat lazy ca `await import(...)` ca să nu plătească costul în skeleton).
- Argv în mod agent: `--resume <sessionId> --cwd <projectPath> --permission-mode <mode> --allowed-tools <csv> [--partial-messages]`.
- Wire format (ambele direcții):
  - **stdin**: `{"type":"send","text":"..."}`, `{"type":"stop"}`.
  - **stdout** line-JSON: `{"type":"ready",mode}`, `{"type":"echo",input}`, `{"type":"agent_event",event}`, `{"type":"error",message}`, `{"type":"exit",code}`.
- Mecanism live:
  - `userMessages()` — async generator care park-uiește pe `new Promise(resolve)` până când `stdin` produce un message nou sau se primește `stop`. Asta menține sesiunea SDK încărcată în memorie între turns (no per-message replay tax).
  - Forward eveniment-cu-eveniment din `for await (const event of query({prompt: userMessages(), options}))` → fiecare event wrapped în `{type:"agent_event",event}`.
  - Track `sessionId` live (SDK îl poate înlocui după prima resume normalization).
- Tratament special:
  - `permissionMode === "bypassPermissions"` activează `allowDangerouslySkipPermissions: true` (SDK explicit opt-in).
  - `AbortError` (interrupt din Swift) → exit cod 0 grațios.

Dependențe sidecar (`Sidecar/package.json:11-13`):
- `@anthropic-ai/claude-agent-sdk: ^0.1.5` — singura dependency runtime.
- Node engine `>= 20`.
- `Sidecar/node_modules/` conține: `@anthropic-ai/`, `@img/` (image), `zod`.

`SidecarLocator` (`Services/SidecarLocator.swift:17-138`):
- `bundledSidecarScript()` → `Bundle.main.resourceURL!/Sidecar/sidecar.js` (eroare tipată `LocateError.sidecarMissing` dacă lipsește).
- `nodeBinary()` — caut cached în UserDefaults, apoi în `/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin`, apoi `zsh -lc 'command -v node'` (login shell pentru asdf/fnm/volta).
- `claudeBinary()` — similar dar și `~/.local/bin/claude` și `~/.claude/local/claude` (instalări per-user).
- `setNodeBinary(_:)` / `setClaudeBinary(_:)` — override-uri din Settings ("Locate manually"). UI-ul pentru picker însă **nu este vizibil** în `SettingsView` actual.

---

## Integrări și dependențe

### Sidecar npm
- `@anthropic-ai/claude-agent-sdk@^0.1.5` (chat live).

### Frameworks Apple folosite (verificat prin imports)
- **SwiftUI** — tot UI-ul.
- **AppKit** — `NSSavePanel`, `NSOpenPanel`, `NSWorkspace.shared.open`, `NSColor`, `NSAppleScript` (Terminal.app launch).
- **Combine** — `import Combine` în `ReplayViewModel.swift` (deși nu se observă consumeri Combine activi, e prezent ca import).
- **Compression** — `compression_encode_buffer` / `compression_decode_buffer` cu `COMPRESSION_ZLIB` în `HTMLRenderer`, `HTMLExtractor`, `Data+Compression`.
- **WebKit (`WKWebView`)** — render HTML → PDF în `ExportViewModel.renderHTMLToPDF` (`@preconcurrency import WebKit`).
- **UniformTypeIdentifiers** — `UTType.html`, `.pdf`, `.plainText` pentru `NSSavePanel.allowedContentTypes`; `import UniformTypeIdentifiers` în `AppDelegate`.
- **SwiftData** — `import SwiftData` în toate cele 4 entități + `DataStore`. `@Model`, `#Unique<...>`, `#Predicate`, `FetchDescriptor`, `ModelContainer`, `ModelConfiguration`.
- **Charts** — `import Charts` în `ToolBreakdownChart.swift` (Swift Charts BarMark).
- **Foundation** — Process, Pipe, FileHandle, DispatchSource, ISO8601DateFormatter, JSONSerialization, NSRegularExpression.

### Procese externe lansate
- `node` (sidecar).
- `git` (`/usr/bin/git` în `GitService.gitExec`).
- `/bin/sh -c` (Chat input bar `!` prefix command).
- `/bin/zsh -lc` (login shell pentru `which` în `SidecarLocator`).
- `Terminal.app` via NSAppleScript / `NSWorkspace.openTerminal`.

---

## Distribuție

`scripts/build-dmg.sh:1-77`:
1. Citește versiunea din `package.json` (root repo) → `Claude-MTW-Replay-<ver>.dmg`.
2. Rulează `swift/sidecar/build.sh` (npm install --omit=dev + copy în Sidecar dir).
3. `xcodegen generate` — regenerează `.xcodeproj` din `project.yml`.
4. `xcodebuild ... -configuration Release -destination 'platform=macOS'` (universal arm64+x86_64 — implicit).
5. Stage `.app` într-un tmp dir + symlink `/Applications`.
6. `hdiutil create -format UDZO -fs HFS+` cu volume name `"Claude MTW Replay <ver>"`.
7. Smoke test: attach/detach (`hdiutil`).

Code signing: `CODE_SIGN_IDENTITY: "-"` (ad-hoc, neînregistrat la Apple Notary). `ENABLE_HARDENED_RUNTIME: YES`.

Info.plist:
- `CFBundleDocumentTypes` — `JSONL Transcript` (`public.json`, role `Viewer`, `LSHandlerRank: Alternate`).
- `LSMinimumSystemVersion: 14.0`.
- `NSSupportsAutomaticTermination: true`, `NSSupportsSuddenTermination: false`.
- `LSApplicationCategoryType: public.app-category.developer-tools`.
- App icon: `AppIcon` din asset catalog.

Resources bundled:
- `Resources/mascot.png` (folosit în `SidebarView` toolbar).
- `Resources/player.html` + `Resources/player.min.html` (template HTML player).
- `Sidecar/` folder (copiat ca tree de post-build script — folder reference, nu flattened ca să nu intre în coliziune nume zod duplicates).

---

## Testare

Doar 2 fișiere de test (XCTest), aprox. 150 linii total:
- `Tests/StreamEventTests.swift` (102 linii) — unit tests pentru `StreamEvent.decode(line:)`: decode ready/echo/error/exit + systemInit/userMessage/userToolResult/assistantBlocks/result + unknown/whitespace/invalid JSON.
- `Tests/ClaudeAgentSkeletonTests.swift` (53 linii) — un singur test E2E care spawn-ează `node sidecar.js --skeleton`, trimite două messages, asertează două `.echo` events. Self-skipping dacă `node` sau sidecar bundle nu sunt prezente.

Test target separat (`Claude-MTW-ReplayTests`) în `project.yml:82-94` cu `TEST_HOST` și `BUNDLE_LOADER` configurat corect; scheme include `Claude-MTW-ReplayTests` la `test` config (`project.yml:103-106`).

Nu există: tests pentru `TranscriptParser` (deși ar fi cele mai utile), tests pentru `HTMLRenderer` round-trip cu `HTMLExtractor`, tests pentru `StatsComputer`, UI tests.

---

## Funcționalități multi-cont

- `~/.claude` = "main" (label) — implicit.
- `~/.claude-yahoo`, `~/.claude-outlook`, `~/.claude-work`, etc. — orice subdirector cu prefix `.claude-` sau `.claude_` care conține `projects/` (`AppState.swift:114-126`).
- Detectare automată: `AccountStore.availableAccounts()` scanează `$HOME` la cerere (apelat pe `onAppear` în `AccountSwitcherMenu`).
- UI: `AccountSwitcherMenu` (toolbar sidebar, `Views/Shared/AccountSwitcherMenu.swift`) afișează lista cu checkmark și label-uri scurte (`.claude-yahoo` → "yahoo").
- Switch: `appState.setClaudeAccount(_:)` salvează în UserDefaults `claudeAccountDir`, resetează selecții, declanșează `.task(id: claudeAccountDir)` în Sidebar care reîncarcă proiectele.
- Discovery: `SessionDiscovery.discoverProjects(claudeAccountDir:)` și `discoverSessions(claudeAccountDir:)` parametrizate.
- Label dinamic: grupul Claude apare ca `Claude Code (yahoo)` în `discoverSessions` când accountul != `.claude` (`SessionDiscovery.swift:137-142`).
- Commit recent `54e566e feat: add claude-yahoo account support (Docker volume mount)` și `64819cc feat: add claude-outlook account support` confirmă feature-ul.

Notă: aspectele "Docker volume mount" și "CLI resolver" din mesajele commit țin de partea Node CLI (`src/`, `bin/`) din repo, nu de aplicația Swift. La nivel Swift, multi-account-ul este pur o chestiune de path scanning + UserDefaults.

---

## Lipsuri/observații

Funcționalități **declarate** dar nelivrate sau stub:

1. **`Views/MenuBar/` — director gol.** Nu există NSStatusItem.
2. **`Views/Sidebar/FavoritesSectionView.swift:2-9`** — hard-coded "No favorites yet" deși `FavoritesViewModel` și `FavoriteEntity` sunt complet implementate; pin/unpin funcționează prin tabel dar lista din sidebar nu render-ează favorite-ele reale.
3. **`Views/Sidebar/TagsSectionView.swift:2-8`** — același tipar; CRUD pentru `TagEntity` există în `DataStore`, dar UI-ul listare/asignare e absent. `TagChipView` e component reutilizabil neconectat.
4. **`Views/Export/ExportSheet.swift:15`** — `Button("Export") { Task { /* TODO */ dismiss() } }` — butonul **NU** apelează `vm.export(turns:options:)`. Funcționalitatea există la nivel de ViewModel (`ExportViewModel.export(turns:options:)`) și e activată indirect prin acțiunea **MD** din tabel + auto-save, dar dialogul direct e incomplet.
5. **Split-view chat** — buton vizibil dar dezactivat în `ChatSessionListView.swift:157-163` cu help "Split-view will land in v0.8.1-swift".
6. **`SessionCompareView`** — explicit "side-by-side display without diff highlighting; semantic per-turn diffing is queued for a follow-up" (`SessionCompareView.swift:8`).
7. **`SidecarLocator.setNodeBinary` / `setClaudeBinary`** — API public există dar nu există UI în `SettingsView` pentru "Locate manually".
8. **`FileWatcher.watchSessionDirectories(...)`** — utilitate gata, dar **nu este conectată** la `ProjectListViewModel` / `SessionListViewModel`. Lista se actualizează doar la Refresh manual sau pe `task(id:)` change.
9. **Bookmarks** — `Bookmark` model + `BookmarkBarView` + suport în `Replay/Edit/Export` există, dar nu există UI pentru a adăuga un bookmark din `ReplayView` (no "B" hotkey or Add Bookmark button).
10. **`SpinnerVerbView` random verb start** — verbe statice, nu reflectă starea aplicației (e doar decorativ).
11. **Cost tracking în chat** — `cumulativeCostUsd` se afișează doar dacă `> 0`; nu există breakdown per turn în UI.
12. **`Color.toHex()`** — folosit doar de `ExportViewModel.renderOptions`; potențial nullable când Color e dinamic (system colors), neacoperit.
13. **Două copii de definiții secret patterns** (`Models/SecretPattern.swift` și `Services/SecretRedactor.swift`) — duplicare cu mici diferențe regex; risk de drift.
14. **Două surse pentru teme** (`Models/Theme.swift` cu SwiftUI Colors și `Services/ThemeService.swift` cu hex strings) — duplicare necesară (SwiftUI vs CSS export), dar fără un singur source-of-truth.
15. **Strict concurrency `complete`** — codul e curat (`@MainActor` peste tot ce trebuie, `Sendable` pe value types, `actor` pentru `ClaudeAgent`), dar `@preconcurrency import WebKit` în `ExportViewModel` semnalează un mic compromis.
16. **Lipsesc parser tests** — `TranscriptParser` (peste 800 linii regex-grele) nu are unit tests.
17. **`ExportSheet` slider speed** are range `0.5...10` dar `ReplayViewModel.speedSteps` merge până la 20; inconsistență minoră.
18. **`KeyboardShortcutsView` listează `⌘1-6`** — în realitate sunt 7 taburi (`⌘1-7`).
