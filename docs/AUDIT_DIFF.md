# Audit diferențe — Web (claude-replay) vs Swift (Claude-MTW-Replay)

Document derivat din [AUDIT_WEB.md](AUDIT_WEB.md) (455 linii) și [AUDIT_SWIFT.md](AUDIT_SWIFT.md) (606 linii). Sursele de adevăr sunt cele două audituri menționate; codul sursă este referit doar prin paths când o citație literală e necesară. Scopul: enumerarea diferențelor — nu repetarea conținutului fiecărui audit.

---

## Versiuni comparate

| Aspect | Web (`claude-replay`) | Swift (`Claude-MTW-Replay`) |
|---|---|---|
| Versiune declarată | `0.8.1` în `package.json:3` ([AUDIT_WEB.md § Versiune](AUDIT_WEB.md#versiune-și-metadate)) | `1.0` în `Info.plist`, `MARKETING_VERSION=1.0.0` în `project.yml:59-60` ([AUDIT_SWIFT.md § Versiune](AUDIT_SWIFT.md#versiune-și-metadate)) |
| Versiune efectivă livrată | `0.8.1` (publicat la npm și ca imagine Docker) | DMG `Claude-MTW-Replay-0.8.1.dmg`; marker DMG citește din `package.json` din root (`scripts/build-dmg.sh:22`), nu din `project.yml`. Sidecar Node bundlat `0.8.0` (`swift/sidecar/package.json:3`) |
| Platformă | Cross-platform (Node 18+; Linux/macOS/Windows via `open`/`start`/`xdg-open`) | macOS-only; `LSMinimumSystemVersion=14.0`, build target macOS 15.0 |
| Runtime | Node.js ≥ 18, browser-side player vanilla JS | Apple silicon + Intel via universal binary; sidecar Node 20+ pentru chat live |
| Limbaj | JavaScript / ES Modules | Swift 5.9, strict concurrency `complete` |
| Persistență | SQLite (`better-sqlite3`) la `${CLAUDE_REPLAY_DATA}/cache.db` cu graceful fallback la no-op ([AUDIT_WEB.md § Persistență](AUDIT_WEB.md#persistență)) | SwiftData (4 `@Model` entități) cu `ModelContainer` persistent ([AUDIT_SWIFT.md § Persistență](AUDIT_SWIFT.md#persistență)) |
| UI Framework | HTML/CSS/JS — template engine ad-hoc bazat pe placeholders `/*NAME*/` peste `template/player.html`, `dashboard.html`, `editor.html` | SwiftUI + MVVM strict (`@Observable` macros, fără `ObservableObject`/`EnvironmentObject`) |
| Distribuție | npm (`bin/claude-replay.mjs`), Docker (`node:22-alpine`), docker-compose | DMG via `hdiutil` + `xcodegen` + `xcodebuild`; ad-hoc code sign (`CODE_SIGN_IDENTITY: "-"`) |
| Ultim commit relevant | seria CLI/web (vezi [AUDIT_WEB.md § CHANGELOG](AUDIT_WEB.md#lipsuriobservații) — CHANGELOG oprit la 0.4.1) | `54e566e feat: add claude-yahoo account support`, `b66fc89 v0.8.1-swift: web parity`, `ca916b2 v0.8.0-swift: interactive Chats tab via @anthropic-ai/claude-agent-sdk` |

---

## Sumar executiv

- **Două aplicații care converg dar nu coincid.** Ambele expun același set de funcționalități "de bază" — parser de transcripte (Claude Code / Cursor / Codex), redaction de secrete, teme, discovery sesiuni, dashboard, editor, replay, export HTML — dar Swift a fost construit pe modelul de paritate cu web (vezi commit `v0.8.1-swift: web parity`), nu ca port complet. Există diferențe semantice atât în interfață, cât și în implementare.
- **Web e cross-platform și remote-capable, Swift e native macOS + chat live.** Web rulează în container (`docker-compose`) sau direct cu `node`, accesibil pe orice browser. Swift e un `.app` macOS care **în plus** poate continua o sesiune existentă via un sidecar Node ce wraps `@anthropic-ai/claude-agent-sdk` (tabul Chats).
- **Versionarea e desincronizată.** `package.json` (web) e `0.8.1`, `Info.plist` (Swift) e `1.0`, sidecar `0.8.0`, dar DMG-ul livrat se cheamă `0.8.1` pentru că `build-dmg.sh` citește din root `package.json`. Există un decalaj clar între marketing version și interna `CFBundleShortVersionString`.
- **Paritate aproape completă pe funcționalitățile sigure.** Player HTML, redaction, parser, themes — toate sunt port 1:1 funcțional în Swift (cu același template `player.min.html` reutilizat pentru export). Cea mai vizibilă lipsă în Swift față de web e tot ce ține de **deployment ca server remote**: terminal WebSocket cu lazygit, dashboard browsabil de oricine pe `127.0.0.1:7331`, subcomanda CLI `extract`, Docker.
- **Cea mai vizibilă lipsă în web față de Swift e chat-ul live.** Web nu are echivalent pentru tabul Chats — există doar editor și replay pasiv. Swift e singura unde poți continua o sesiune Claude Code direct din UI.

---

## Paritate funcțională (ce există în AMBELE)

| Funcționalitate | Web (cum/locație) | Swift (cum/locație) | Note |
|---|---|---|---|
| Parser Claude Code | `src/parser.mjs:529` `parseTranscript` cu absorbție user-tool_result și `attachToolResults` ([AUDIT_WEB.md § Parser](AUDIT_WEB.md#parser-și-formate-suportate)) | `Services/TranscriptParser.swift:16-847` — port 1:1 funcțional declarat ([AUDIT_SWIFT.md § Parser](AUDIT_SWIFT.md#parser-și-formate-suportate)) | Ambele aplică `cleanSystemTags` cu același set de tag-uri |
| Parser Cursor | `parser.mjs:106-112,626-635` — re-marchează blocurile assistant cu excepția ultimului ca `thinking` | `TranscriptParser.swift:680-691` — exact aceeași transformare | Ambele normalizează shape Claude Code |
| Parser Codex CLI | `parseCodexTranscript` în `parser.mjs:314-522` cu `parseCodexPatch`, `extractCodexUserText`, event-based parser | `TranscriptParser.swift` `parseCodexTranscript`, `parseCodexPatch`, `extractCodexUserText` | Mapări identice: `exec_command`→Bash, `apply_patch`→Write/Edit |
| Redaction secrets | `src/secrets.mjs` — 11 patterns + `redactObject` recursiv ([AUDIT_WEB.md § Redaction](AUDIT_WEB.md#redaction--secrets)) | `Models/SecretPattern.swift` + `Services/SecretRedactor.swift` — 11 patterns aproape identice; **duplicare internă în Swift** ([AUDIT_SWIFT.md § Redaction](AUDIT_SWIFT.md#redaction--secrets)) | Aceleași categorii: `private_key`, `aws_key`, `sk_ant_key`, `sk_key`, `bearer`, `jwt`, `connection_string`, `env_var`, `hex_token` etc. |
| Teme | `src/themes.mjs` — 8 built-in (`claude-dark/light`, `tokyo-night`, `monokai`, `solarized-dark`, `github-light`, `dracula`, `bubbles`) + JSON custom prin `--theme-file` ([AUDIT_WEB.md § Teme](AUDIT_WEB.md#teme)) | `Models/Theme.swift` + `Services/ThemeService.swift` — același set 8 + paralel SwiftUI Color / hex strings ([AUDIT_SWIFT.md § Teme](AUDIT_SWIFT.md#teme)) | Default CLI: `tokyo-night`; default renderer: `claude-dark` (web). Swift folosește per-app `selectedThemeName` din UserDefaults |
| Discovery sesiuni | `src/resolve-session.mjs` (CLI single-ID resolver) + `discoverSessions` în `editor-server.mjs:329-430` (server tree) ([AUDIT_WEB.md § Discovery](AUDIT_WEB.md#session-discovery--resolver)) | `Services/SessionDiscovery.swift:74-429` + `Services/SessionResolver.swift:15-147` — port direct ([AUDIT_SWIFT.md § Discovery](AUDIT_SWIFT.md#session-discovery--resolver)) | Ambele scanează `~/.claude*`, `~/.cursor`, `~/.codex` cu aceleași pattern-uri |
| Player | `template/player.html` (2725 linii) și `player.min.html` (135 linii minificat) — JS vanilla self-contained ([AUDIT_WEB.md § Player](AUDIT_WEB.md#funcționalități--player-html-generat)) | Două players paralele: native `ReplayView` + reutilizarea `Resources/player.min.html` la export ([AUDIT_SWIFT.md § Replay](AUDIT_SWIFT.md#funcționalități--replay)) | Vezi secțiunea "Implementări divergente" |
| Editor turns | Trei panouri în `editor.html` + `editor-server.mjs:911-1421` API ([AUDIT_WEB.md § Editor](AUDIT_WEB.md#funcționalități--web-editor)) | `EditorView` + `EditorViewModel` (`HSplitView` cu `TurnBrowserPanel`/`TurnEditorPanel`) ([AUDIT_SWIFT.md § Editor](AUDIT_SWIFT.md#funcționalități--editor)) | Web are bulk Include/Exclude All; Swift nu (declarat ca lipsă, [AUDIT_SWIFT.md § Lipsuri 4-7](AUDIT_SWIFT.md#lipsuriobservații)) |
| Export HTML | `src/renderer.mjs` `render()` cu placeholders + `deflateSync+base64` compression ([AUDIT_WEB.md § Renderer](AUDIT_WEB.md#renderer-și-template-engine)) | `Services/HTMLRenderer.swift:24-195` cu `compression_encode_buffer` `COMPRESSION_ZLIB` + stripare manuală header/checksum pentru compatibilitate raw-deflate ([AUDIT_SWIFT.md § Export](AUDIT_SWIFT.md#funcționalități--export)) | Ambele produc același template HTML output; ambele suportă `--no-compress` / `compress=false` |
| Dashboard sessions | `template/dashboard.html` (2938 linii) cu sidebar proiecte + heatmap + tabel sortabil ([AUDIT_WEB.md § Dashboard](AUDIT_WEB.md#funcționalități--web-dashboard)) | `Views/Dashboard/DashboardView.swift` cu `ActivityHeatmapView` + `SessionTableView` ([AUDIT_SWIFT.md § Dashboard](AUDIT_SWIFT.md#funcționalități--dashboard)) | Coloane identice: Session ID / Preview / Date / Duration / Turns / Size / Actions. Heatmap GitHub-style în ambele |
| Stats | Lazy `POST /api/session-stats` cu cache SQLite în `computeSessionStats` (`editor-server.mjs:730-853`) | `Services/StatsComputer.swift:3-99` + `StatsViewModel` cu cache SwiftData `SessionStatsEntity` | Metrici identice: tool breakdown, bash commands, files read/edited, agents, duration |
| Integrare git | `POST /api/git-details` (`editor-server.mjs:497-519`) cu branch, branches, log graph | `Services/GitService.swift:22-66` cu `getGitInfo`/`getGitDetails`, ASCII graph identic | Ambele read-only — fără fetch/pull/push/diff |
| Search | `POST /api/search` (`editor-server.mjs:1176-1264`) — caut în transcript-uri proiect | `Services/SearchService.swift:3-44` + `GlobalSearchView` (Cmd+F) — case-insensitive substring, scope proiect curent sau global | Web suportă cross-proiect implicit; Swift e Claude-only (nu caută în cursor/codex) |
| Deep links / Keyboard shortcuts | Player: `Space/K`, `→/L`, `←/H`, `Shift+→`, `T`, `Shift+T`. Dashboard: `?`, `1/2/3/Esc`. Deep link URL `#turn=N` ([AUDIT_WEB.md § Keyboard](AUDIT_WEB.md#funcționalități--player-html-generat)) | Replay: `Space/K`, `→/L`, `←/H`, `Shift+→/←`, `T`, `Esc`. Navigate: `Cmd+1..7`, `Cmd+F`, `Cmd+E`, `Cmd+/` ([AUDIT_SWIFT.md § Replay](AUDIT_SWIFT.md#funcționalități--replay)) | Set similar pentru replay; Swift adaugă Cmd-based standard macOS; web folosește URL hash `#turn=N` |
| Favorites | `getFavorites/addFavorite/removeFavorite/isFavorite` în `db.mjs`; `/api/favorites` (`editor-server.mjs:1304-1316`) | `FavoritesViewModel` + `FavoriteEntity` SwiftData — CRUD complet | **În Swift sidebar e stub** ("No favorites yet" hard-coded — [AUDIT_SWIFT.md § Lipsuri 2](AUDIT_SWIFT.md#lipsuriobservații)) |
| Tags | `tags` table + `/api/tags` (`editor-server.mjs:1320-1328`) — dar `getTagsForSession` nu e folosit la UI ([AUDIT_WEB.md § Lipsuri](AUDIT_WEB.md#lipsuriobservații)) | `TagEntity` SwiftData CRUD complet în `DataStore` | **Ambele au UI stub** (no listing/assignment) — feature pre-disponibil în DB |
| Plans tab | `Plans` sub-tab cu `EnterPlanMode/ExitPlanMode` + `*/plans/*` ([AUDIT_WEB.md § Dashboard](AUDIT_WEB.md#funcționalități--web-dashboard)) | `PlansListView` cu `~/.claude/plans/<encoded-dir>/*.md` + `MarkdownTextView` preview | Sursele de date diferă: web listează apelurile tool, Swift listează fișiere `.md` |
| CLAUDE.md / MEMORY.md | Sub-tab display (`editor-server.mjs:625-631`) | `ProjectFilesView` cu `MarkdownTextView` | Paritate completă; ambele rezolvă path-ul prin "claude dir → project path" decoding |
| Session compare | Overlay în `dashboard.html:1288-1289` cu `POST /api/transcript` | `SessionCompareView` — sheet cu `HSplitView` side-by-side dar **fără** diff highlighting (deferred) | Ambele au limitarea "doar 2 sesiuni" |

---

## Doar în Web (lipsă în Swift)

- **Subcomanda CLI `extract`** — recuperează `turns` + `bookmarks` dintr-un replay HTML deja generat (`bin/claude-replay.mjs:132-158`, `src/extract.mjs:76`). În Swift există `HTMLExtractor` (`Services/HTMLExtractor.swift:13-198`) care implementează aceeași reverse-operație, **dar nu e expus în UI**; e doar API intern. ([AUDIT_WEB.md § Entry points](AUDIT_WEB.md#entry-points))
- **Distribuție prin Docker / docker-compose** — `Dockerfile` (`node:22-alpine` + lazygit + git) și `docker-compose.yml` cu volume read-only pentru `~/.claude*`, `~/.cursor`, `~/.codex` și volum rw pe `$HOME`. Modul "server local accesibil în browser" e exclusiv web. ([AUDIT_WEB.md § Distribuție](AUDIT_WEB.md#distribuție))
- **Distribuție prin npm** — `bin: { "claude-replay": "bin/claude-replay.mjs" }` cu cross-platform `--open`. Swift nu are echivalent CLI. ([AUDIT_WEB.md § Distribuție](AUDIT_WEB.md#distribuție))
- **Terminal WebSocket cu node-pty + xterm.js** — `src/terminal.mjs` (`/ws/terminal`) spawn-uiește `lazygit`/shell în PTY. UI în `template/lazygit.html` cu `xterm.js` + addons. Swift are doar "Open in Terminal" via AppleScript spre `Terminal.app`, nu un terminal embedded. ([AUDIT_WEB.md § Terminal](AUDIT_WEB.md#terminal-integration))
- **Pagina LazyGit dedicată** — rută `/lazygit` accesibilă din header și din "Open LazyGit" buttons din dashboard. Swift n-are equivalent. ([AUDIT_WEB.md § Dashboard](AUDIT_WEB.md#funcționalități--web-dashboard))
- **Player HTML self-contained ca artefact embeddable** — output-ul `claude-replay <input> -o out.html` produce un fișier HTML complet portabil ce poate fi distribuit fără nicio dependență. Swift produce același artefact dar **doar prin export sheet din UI** — nu există un mod CLI/batch. ([AUDIT_WEB.md § Renderer](AUDIT_WEB.md#renderer-și-template-engine))
- **SSE live updates** — `GET /api/events` emite `sessions-changed` la 10s dacă numărul total de sesiuni se schimbă (`editor-server.mjs:1342-1373`); client-side `EventSource`. Swift are `FileWatcher` echivalent dar **nu e conectat la UI** ([AUDIT_SWIFT.md § Lipsuri 8](AUDIT_SWIFT.md#lipsuriobservații)). ([AUDIT_WEB.md § Dashboard](AUDIT_WEB.md#funcționalități--web-dashboard))
- **Account switcher pentru `~/.claude*` injectat runtime** — `injectShared` în editor-server scanează `.claude(-_).+` și injectează dropdown-ul în HTML. (Există echivalent Swift dar fără injection — vezi multi-cont în Swift.) ([AUDIT_WEB.md § Editor](AUDIT_WEB.md#funcționalități--web-editor))
- **OG/Twitter meta tags** — `og:title`, `og:description`, `og:type`, `og:image` + `twitter:card=summary_large_image` injectate în player HTML (`player.html:9-16`). Default `og:image` hardcodat la `es617.github.io/claude-replay/og.png`. Swift export are flag-urile dar nu un default hosted similar. ([AUDIT_WEB.md § Player](AUDIT_WEB.md#funcționalități--player-html-generat))
- **Session chaining (multi-input concatenare)** — `claude-replay session1 session2 …` (max 20) concatenează cronologic și reindexează turns (`bin/claude-replay.mjs:247-270`). Swift nu suportă concatenare. ([AUDIT_WEB.md § Parser](AUDIT_WEB.md#parser-și-formate-suportate))
- **Build-time minification** — `scripts/build-template.mjs` cu esbuild → `player.min.html` (~135 vs. 2725 linii). Swift include direct `player.min.html` produs de pipeline-ul web. ([AUDIT_WEB.md § Renderer](AUDIT_WEB.md#renderer-și-template-engine))
- **`--bookmarks FILE` și `--mark "N:Label"`** — bookmarks via CLI flags repetabile sau JSON file. Swift nu expune adăugare programatică de bookmarks din afara UI. ([AUDIT_WEB.md § CLI](AUDIT_WEB.md#funcționalități--cli))
- **Privacy CSRF check** — verificare anti-CSRF în `editor-server.mjs:914-925` care respinge Origin străin. Specific contextului server local — irrelevant pentru Swift native. ([AUDIT_WEB.md § Editor](AUDIT_WEB.md#funcționalități--web-editor))
- **Browse arbitrary path (restricționat la `$HOME`)** — `POST /api/browse` (`editor-server.mjs:290-327`) pentru "Open Folder" în editor. Swift folosește `NSOpenPanel` standard. ([AUDIT_WEB.md § Editor](AUDIT_WEB.md#funcționalități--web-editor))
- **Transcript overlay cu search + filtre per rol** — `POST /api/transcript` cu search box, Enter/Shift+Enter navigation, filtre per rol. Swift are `TranscriptView` cu `TranscriptSearchBar` + `TranscriptFilterBar` echivalente. (De fapt: paritate, dar diferă în interaction model.)
- **End-to-end testing extensiv** — `@playwright/test` 58 e2e + ~140 unit (`test/test-*.mjs`). Swift are doar **2 fișiere** XCTest (≈150 linii total), zero coverage pentru parser. ([AUDIT_WEB.md § Testare](AUDIT_WEB.md#testare) vs [AUDIT_SWIFT.md § Testare](AUDIT_SWIFT.md#testare))
- **`--theme-file FILE`** — încărcare JSON custom theme care moștenește variabilele `tokyo-night`. Swift nu expune custom theme import în UI. ([AUDIT_WEB.md § Teme](AUDIT_WEB.md#teme))

---

## Doar în Swift (lipsă în Web)

- **Tab Chats live cu `@anthropic-ai/claude-agent-sdk`** — `ChatViewModel` + `ClaudeAgent` actor + sidecar Node (`Sidecar/sidecar.js`) care wraps `query()` din SDK. Permite continuarea unei sesiuni existente cu streaming tokens. Web nu are echivalent. ([AUDIT_SWIFT.md § Chats](AUDIT_SWIFT.md#funcționalități--chats-chat-interactiv))
- **Sidecar Node bundlat în .app** — `swift/Claude-MTW-Replay/Sidecar/sidecar.js` (208 linii) copiat în `.app/Contents/Resources/Sidecar/` de post-build script. `SidecarLocator` găsește `node` în `/opt/homebrew/bin`, `/usr/local/bin`, fallback `zsh -lc 'command -v node'`. ([AUDIT_SWIFT.md § Sidecar](AUDIT_SWIFT.md#sidecar-node--sidecarsidecarjs))
- **Multi-account support automat în UI** — `AccountStore.availableAccounts()` scanează `$HOME` pentru orice `.claude-*` cu `projects/`; auto-discovery `claude-yahoo`, `claude-outlook`, `claude-work` etc. `AccountSwitcherMenu` cu checkmark. Persistat în UserDefaults. ([AUDIT_SWIFT.md § Multi-cont](AUDIT_SWIFT.md#funcționalități-multi-cont))
- **Persistență SwiftData cu favorite / tags** — 4 entități (`SessionMetaEntity`, `SessionStatsEntity`, `FavoriteEntity`, `TagEntity`) cu `#Unique`, `#Predicate`, `FetchDescriptor`. ModelContainer persistent on-disk. (Web are echivalent SQLite — dar nu folosește o ORM declarativă.)
- **SwiftUI nativ Window + Settings macOS** — `WindowGroup { ContentView() }` cu `minWidth: 900, minHeight: 600`, default `1200×800` + `Settings { SettingsView() }` (fereastra standard de Preferences). ([AUDIT_SWIFT.md § Lifecycle](AUDIT_SWIFT.md#entry-points--lifecycle))
- **WKWebView pentru render HTML → PDF** — `ExportViewModel.renderHTMLToPDF` randează HTML într-un `WKWebView` offscreen → `webView.pdf(configuration: WKPDFConfiguration())`. Web export PDF e via browser print dialog (nu programatic). ([AUDIT_SWIFT.md § Export](AUDIT_SWIFT.md#funcționalități--export))
- **Build DMG cu hdiutil** — `scripts/build-dmg.sh` cu staging tmp dir + symlink `/Applications` + `hdiutil create -format UDZO -fs HFS+` + smoke test attach/detach. ([AUDIT_SWIFT.md § Distribuție](AUDIT_SWIFT.md#distribuție))
- **Document types (`CFBundleDocumentTypes`)** — `JSONL Transcript` cu `public.json`, role `Viewer`. Permite drag-drop pe icon și "Open With" din Finder. `AppDelegate.application(_:open:)` filtrează `.jsonl` și emite notification. ([AUDIT_SWIFT.md § Distribuție](AUDIT_SWIFT.md#distribuție))
- **MVVM strict (Observation framework)** — `@Observable` macros peste tot, **fără** `ObservableObject`/`EnvironmentObject`. Pasarea stării exclusiv prin `AppState` + Bindings. Concurrency mode `complete`. ([AUDIT_SWIFT.md § Arhitectură](AUDIT_SWIFT.md#arhitectură-generală))
- **Swift Charts (`import Charts`)** — `ToolBreakdownChart` cu `BarMark` orizontal cu paletă temă-aware. Web folosește HTML/CSS bare pentru stats. ([AUDIT_SWIFT.md § Stats](AUDIT_SWIFT.md#funcționalități--stats))
- **`@` / `!` / `#` prefix chips în chat input** — `@` deschide NSOpenPanel pentru inline file content (64KB max), `!` rulează shell command (`/bin/sh -c`) și inlinează output (16KB max), `#` adaugă literal pentru directive memory. Parity cu TUI Claude Code. ([AUDIT_SWIFT.md § Chats](AUDIT_SWIFT.md#funcționalități--chats-chat-interactiv))
- **Mode toggle (Plan / Accept Edits / Default)** — `ModeToggleView` în chat input bar. `bypassPermissions` ascuns din UI deliberat. ([AUDIT_SWIFT.md § Chats](AUDIT_SWIFT.md#funcționalități--chats-chat-interactiv))
- **Cost tracking în chat** — `lastTurnCostUsd` + `cumulativeCostUsd` din evenimentul `result.total_cost_usd`. Web nu accesează API-ul Claude direct → nu are cost. ([AUDIT_SWIFT.md § Chats](AUDIT_SWIFT.md#funcționalități--chats-chat-interactiv))
- **SpinnerVerbView (187 verbe cu shimmer reverse-sweep)** — toolbar spinner cu cycle 2.4s. Verbele provin din `theclaude-mtw/src/constants/spinnerVerbs.ts` (vezi [AUDIT_WEB.md § Lipsuri](AUDIT_WEB.md#lipsuriobservații) — există și fișier echivalent în web, `spinnerVerbs.mjs`, dar nu e folosit la UI). ([AUDIT_SWIFT.md § MenuBar](AUDIT_SWIFT.md#funcționalități--menubar))
- **CommandMenu("Navigate") + Help → Keyboard Shortcuts** — `Cmd+1..7` pentru `AppTab.allCases`, `Cmd+F` search, `Cmd+E` export, `Cmd+/` help. Web folosește `1/2/3` (single key) cu `Esc` pentru a închide. ([AUDIT_SWIFT.md § Lifecycle](AUDIT_SWIFT.md#entry-points--lifecycle))
- **FileWatcher cu `DispatchSourceFileSystemObject`** — wrapper cu mask `.write/.delete/.rename/.extend` și diff `lastKnownContents`. Echivalentul SSE din web; **dar nu e wired la UI**. ([AUDIT_SWIFT.md § Lipsuri 8](AUDIT_SWIFT.md#lipsuriobservații))

---

## Implementări divergente ale acelorași funcționalități

### Parser transcripte

Ambele aplicații suportă aceleași 3 formate (Claude Code / Cursor / Codex). Algoritmul e port 1:1, dar limbajul diferă fundamental:

- **Web** — `src/parser.mjs` (697 linii) cu JavaScript și manipulare directă a obiectelor JSON. Folosește `JSON.parse` line-by-line, accesări `obj.type`/`obj.role` direct. ([AUDIT_WEB.md § Parser](AUDIT_WEB.md#parser-și-formate-suportate))
- **Swift** — `Services/TranscriptParser.swift` (peste 800 linii) cu `JSONSerialization` pentru parsing și `AnyCodable` (type-erased Codable wrapper) pentru tool input heterogen. `Turn`/`AssistantBlock`/`ToolCall` sunt value types Codable cu `BlockKind` enum. ([AUDIT_SWIFT.md § Parser](AUDIT_SWIFT.md#parser-și-formate-suportate))

Cazurile edge sunt tratate identic (Cursor: re-marchează tot ce nu e ultimul bloc ca `thinking`; Codex: `exec_command`→Bash, `apply_patch`→Write/Edit cu detection isNew). Tag-urile sistem stripped sunt aceleași: `<system-reminder>`, `<task-notification>`, `<user_query>`, etc.

**Risc de drift:** Web are 46 teste `it` în `test-parser.mjs`; Swift **nu are** unit tests pentru parser ([AUDIT_SWIFT.md § Lipsuri 16](AUDIT_SWIFT.md#lipsuriobservații)).

### Redaction

- **Web** — `src/secrets.mjs` cu o singură sursă: 11 pattern-uri în `SECRET_PATTERNS`, `redactSecrets(text)` aplică toate, `redactObject(obj)` walk recursiv pe stringuri. ([AUDIT_WEB.md § Redaction](AUDIT_WEB.md#redaction--secrets))
- **Swift** — **două surse paralele:** `Models/SecretPattern.swift` (struct cu 11 patterns) și `Services/SecretRedactor.swift` (enum cu 11 patterns near-identice). Duplicare cu mici diferențe regex, marcată ca "risk de drift" în [AUDIT_SWIFT.md § Lipsuri 13](AUDIT_SWIFT.md#lipsuriobservații).

Categoriile sunt aceleași în ambele, dar Swift trebuie să sincronizeze două copii când apare un pattern nou. Web are 17 teste unit; Swift n-are.

### Player (HTML embedded vs SwiftUI native)

Aceeași funcționalitate exprimată în două medii diferite:

- **Web** — singurul player, HTML self-contained `template/player.html` (2725 linii) sau minified `player.min.html` (135). Animație block-by-block JS cu `ANIMATE_MIN_DELAY`, tool grouping (consecutive `tool_use` → `tool-group` colapsabil), diff view cu CSS `+`/`−`, splash screen, deep links `#turn=N`. ([AUDIT_WEB.md § Player](AUDIT_WEB.md#funcționalități--player-html-generat))
- **Swift** — **două players paralele:**
  1. **Native** — `ReplayView` + `ReplayViewModel` cu `LazyVStack(ForEach turns) { ReplayTurnView }`, `revealedBlockCount`, `play()` async loop cu `adaptiveDelay = min(max(charCount * 0.03, 0.6), 10.0) / speed`. Tool grouping pentru ≥5 `toolUse` consecutive în `CollapsedToolGroupView`. ([AUDIT_SWIFT.md § Replay](AUDIT_SWIFT.md#funcționalități--replay))
  2. **HTML export** — același `player.min.html` bundlat în `Resources/`, randat prin `HTMLRenderer` identic cu web pentru a produce un artefact portabil.

**Diferență notabilă:** Web player are `Splash`, `Iframe detection (compact mode)`, `Bookmarks/Chapters dropdown` interactive — Swift native nu are splash; `BookmarkBarView` există dar **nu există UI pentru a adăuga un bookmark din ReplayView** ([AUDIT_SWIFT.md § Lipsuri 9](AUDIT_SWIFT.md#lipsuriobservații)).

**Threshold tool grouping** — web grupează toate `tool_use` consecutive (fără prag explicit, [AUDIT_WEB.md § Lipsuri](AUDIT_WEB.md#lipsuriobservații)); Swift folosește `≥5` ([AUDIT_SWIFT.md § Replay](AUDIT_SWIFT.md#funcționalități--replay)). Inconsistență.

### Persistență (SQLite better-sqlite3 vs SwiftData)

- **Web** — `src/db.mjs` (205 linii). `better-sqlite3`, PRAGMA `journal_mode=WAL`, `synchronous=NORMAL`. 4 tabele cu chei explicite (`session_meta`, `session_stats`, `favorites`, `tags`). **Graceful fallback**: dacă `better-sqlite3` nu se instalează (lipsă toolchain native), modulul DB e nul și toate funcțiile devin no-ops. ([AUDIT_WEB.md § Persistență](AUDIT_WEB.md#persistență))
- **Swift** — `Persistence/DataStore.swift` cu `ModelContainer` SwiftData. 4 `@Model` entități echivalente. `#Unique<path>`, `#Predicate`, `FetchDescriptor`. **Fără fallback** — dacă schema e incompatibilă, app crash-uiește. ([AUDIT_SWIFT.md § Persistență](AUDIT_SWIFT.md#persistență))

Schema e izomorfică între cele două. Diferența principală: Swift folosește `@MainActor`-isolated singleton, web folosește un singur fișier `cache.db` partajat între request-uri HTTP (thread-safe prin SQLite WAL).

### Discovery sesiuni

Aceleași 3 root-uri scanate (`~/.claude*`, `~/.cursor`, `~/.codex`), aceleași pattern-uri de fișiere.

- **Web** — `src/resolve-session.mjs` (126 linii, CLI single-ID) + `discoverSessions` în `editor-server.mjs:329-430` (server tree). Două căi paralele.
- **Swift** — `Services/SessionDiscovery.swift:74-429` + `Services/SessionResolver.swift:15-147`. Port direct, dar separat în două servicii.

**Diferență:** Web reîncarcă lista de sesiuni la fiecare request `GET /api/sessions` (cu cache SQLite invalidat prin mtime). Swift reîncarcă **explicit la Refresh button sau pe `task(id: claudeAccountDir)` change**. `FileWatcher` există în Swift dar nu e conectat la `ProjectListViewModel`/`SessionListViewModel` ([AUDIT_SWIFT.md § Lipsuri 8](AUDIT_SWIFT.md#lipsuriobservații)).

### Export HTML

- **Web** — `src/renderer.mjs` cu `deflateSync` (Node `zlib`) + `base64`, default. Sau JSON brut escape-uit cu `escapeJsonForScript` la `--no-compress`. ([AUDIT_WEB.md § Renderer](AUDIT_WEB.md#renderer-și-template-engine))
- **Swift** — `Services/HTMLRenderer.swift:24-195` cu `compression_encode_buffer` `COMPRESSION_ZLIB` (Apple Compression framework) + **strip manual header zlib (`0x78 0x9C`) și Adler-32 (4 ultimi bytes)** pentru compatibilitate cu raw-deflate. ([AUDIT_SWIFT.md § Export](AUDIT_SWIFT.md#funcționalități--export))

Output-ul e bit-identic — același template `player.min.html` cu aceleași placeholders. Diferă doar pipeline-ul de compresie (zlib vs raw deflate cu manipulare manuală).

### Themes

Ambele expun aceleași 8 teme și aceleași 16 variabile CSS.

- **Web** — `src/themes.mjs` cu o singură sursă: dict de teme cu hex strings. ([AUDIT_WEB.md § Teme](AUDIT_WEB.md#teme))
- **Swift** — **două surse paralele:** `Models/Theme.swift` (SwiftUI `Color` cu hex parser/`toHex()` round-trip) și `Services/ThemeService.swift` (hex strings pentru CSS export). Duplicare necesară (SwiftUI vs CSS), dar fără un single source of truth — [AUDIT_SWIFT.md § Lipsuri 14](AUDIT_SWIFT.md#lipsuriobservații).

**Custom themes:** Web suportă `--theme-file FILE` (JSON care moștenește din `tokyo-night`); Swift n-are.

---

## Decalaje de versiune și sincronizare

**Status versiune (mai 2026):**

- Web component: `package.json:3 = 0.8.1`. CHANGELOG oprit la `0.4.1` (versiunile 0.5–0.8.1 nedocumentate explicit, vezi [AUDIT_WEB.md § Lipsuri](AUDIT_WEB.md#lipsuriobservații)).
- Swift app: `CFBundleShortVersionString = 1.0`, `MARKETING_VERSION = 1.0.0`. Dar DMG-ul livrat se numește `Claude-MTW-Replay-0.8.1.dmg` pentru că `scripts/build-dmg.sh:22` citește din `package.json` din rădăcina repo-ului (web), nu din `project.yml`. Inconsistență de marketing.
- Sidecar Node bundlat: `swift/sidecar/package.json:3 = 0.8.0`. Cu o versiune în urmă față de web și față de DMG-ul Swift.

**Indicii din commit-uri:**

- `ca916b2 v0.8.0-swift: interactive Chats tab via @anthropic-ai/claude-agent-sdk` — versionarea `-swift` indică un branch paralel de releasing pentru aplicația macOS.
- `b66fc89 v0.8.1-swift: web parity` — paritate explicită declarată la 0.8.1. Asta e momentul când Swift a ajuns la feature parity cu web 0.8.1 (cu excepțiile listate mai sus).
- `64819cc feat: add claude-outlook account support (Docker + CLI resolver)` și `54e566e feat: add claude-yahoo account support (Docker volume mount)` — multi-cont a apărut **întâi în web** (CLI resolver + Docker volume), apoi în Swift (UI auto-discovery).

**Componente sincronizate (semantic 1:1):**

- Parser-ul (`parser.mjs` ↔ `TranscriptParser.swift`)
- Redaction patterns (11 categorii identice, deși Swift le duplică intern)
- Themes (8 built-in)
- Discovery paths (`~/.claude*`, `~/.cursor`, `~/.codex`)
- Player HTML template (același `player.min.html` reutilizat)
- Schema persistență (`session_meta`, `session_stats`, `favorites`, `tags`)
- Stats metrics (tool breakdown, files, agents, etc.)
- Git info (read-only summary, ASCII graph)

**Componente nesincronizate / divergente:**

- Versiunea Swift trebuie aliniată cu web (sau `build-dmg.sh` trebuie să citească din `project.yml`, nu din rădăcină).
- Sidecar 0.8.0 e cu o versiune în urmă față de DMG.
- Tool grouping threshold (web: 1+, Swift: 5+).
- Bookmarks: web are CLI flags + JSON import, Swift n-are UI add.
- E2E coverage: 58 Playwright web vs 0 Swift UI tests.

---

## Recomandări pentru paritate completă

1. **Port `extract` ca acțiune în UI Swift.** `HTMLExtractor` există deja (`Services/HTMLExtractor.swift`); doar trebuie expus printr-un `NSOpenPanel` + acțiune "Import HTML Replay" în menu File. ([AUDIT_WEB.md § Entry points](AUDIT_WEB.md#entry-points), [AUDIT_SWIFT.md § Export](AUDIT_SWIFT.md#funcționalități--export))
2. **Wire `FileWatcher` la `SessionListViewModel`.** Echivalentul SSE din web. Cod gata, doar consumer-ul lipsește. ([AUDIT_SWIFT.md § Lipsuri 8](AUDIT_SWIFT.md#lipsuriobservații))
3. **Fix `ExportSheet` button "Export"** — apel `vm.export(turns:options:)` în loc de `/* TODO */`. Funcționalitatea e gata la ViewModel level. ([AUDIT_SWIFT.md § Lipsuri 4](AUDIT_SWIFT.md#lipsuriobservații))
4. **Implementează Favorites/Tags listing în sidebar Swift.** CRUD-ul SwiftData există; UI-ul `FavoritesSectionView` și `TagsSectionView` sunt stub-uri. ([AUDIT_SWIFT.md § Lipsuri 2-3](AUDIT_SWIFT.md#lipsuriobservații))
5. **Adaugă unit tests pentru `TranscriptParser`** în Swift — port direct al fixture-urilor din `test/fixture*.jsonl`. Riscul de drift dintre cele două parsere e major; web are 46 teste, Swift are 0. ([AUDIT_SWIFT.md § Lipsuri 16](AUDIT_SWIFT.md#lipsuriobservații))
6. **Unifică tool grouping threshold** — fie 1+ (web) fie 5+ (Swift). Inconsistența de threshold afectează output-ul vizual diferit pentru aceeași sesiune.
7. **Sincronizează versionarea**: fie marketing version Swift = 0.8.1 (potrivit cu `package.json` și DMG-ul produs), fie `build-dmg.sh` să folosească `project.yml` ca sursă. Actualizează și sidecar la 0.8.1. Reia CHANGELOG-ul pentru versiunile 0.5–0.8.1.
8. **Deduplicare în Swift**: o singură sursă pentru secret patterns (între `Models/SecretPattern.swift` și `Services/SecretRedactor.swift`) și un single source of truth pentru teme (decodare hex/Color un singur loc). ([AUDIT_SWIFT.md § Lipsuri 13-14](AUDIT_SWIFT.md#lipsuriobservații))
9. **Port chat live (Chats tab) în web** sau **deprecă-l explicit**. E feature-ul flagship Swift; dacă obiectivul e paritate, web ar trebui să poată face fetch direct la SDK (greu — dependențe diferite) sau să facă proxy la sidecar. Alternativa e să-l declarăm Swift-only oficial.
10. **Port "Add Bookmark" în Replay Swift** — buton/hotkey "B" în `ReplayView` care append-uiește la `vm.bookmarks` și salvează în SwiftData. Restul stack-ului (model + display + export) e deja gata. ([AUDIT_SWIFT.md § Lipsuri 9](AUDIT_SWIFT.md#lipsuriobservații))
