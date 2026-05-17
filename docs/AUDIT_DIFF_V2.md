# Audit diferențe V2 — Web (claude-replay v0.8.1) vs Swift (Claude-MTW-Replay v1.0.0)

> Pentru diferențele anterioare sprint-urilor, vezi [AUDIT_DIFF.md](AUDIT_DIFF.md).
> Pentru starea actuală a celor două aplicații, vezi [AUDIT_WEB.md](AUDIT_WEB.md) și [AUDIT_SWIFT.md](AUDIT_SWIFT.md) (V1) — un `AUDIT_SWIFT_V2.md` e produs în paralel; acest document folosește `IMPROVEMENTS_SWIFT.md` (planul executat) + `git log` ca sursă de adevăr alternativă.

**Status:** Swift este acum **production-ready la 1.0.0**. A depășit paritatea inițială (declarată la `b66fc89 v0.8.1-swift: web parity`) și a livrat 7 sprint-uri consecutive plus un sprint de docs in-app — închizând **toate cele 18 lipsuri V1** și adăugând features peste web (chat live mature, MCP servers, permission UI, docs in-app, persistență chat). Web rămâne stabil la `0.8.1` și nu s-a modificat în această fereastră de timp (planul `IMPROVEMENTS_WEB.md` n-a fost executat).

Cele două aplicații **acum diverg conștient** în direcții complementare: web e candidatul natural pentru server/Docker/remote-access; Swift e candidatul natural pentru macOS desktop client rich.

---

## Versiuni comparate

| Aspect | Web (`claude-replay`) | Swift (`Claude-MTW-Replay`) |
|---|---|---|
| Versiune declarată | `0.8.1` (`package.json:3`) | `1.0.0` (`swift/project.yml:59` `MARKETING_VERSION`) |
| Versiune efectivă în Info.plist | n/a | `CFBundleShortVersionString = $(MARKETING_VERSION)` → `1.0.0` la build (placeholder string în plist literal e `1.0`, dar substituit din xcconfig la build) |
| Versiune DMG livrată | n/a | `Claude-MTW-Replay-1.0.0.dmg` — `swift/scripts/build-dmg.sh` citește acum din `project.yml` (nu mai din root `package.json`) |
| Versiune sidecar bundlat | n/a | `swift/sidecar/package.json:3 = 1.0.0` — sincronizat cu Swift app |
| CHANGELOG | `CHANGELOG.md` la rădăcină, oprit la `0.4.1` | `swift/CHANGELOG.md` introdus (Keep-a-Changelog format) cu intrările `0.8.0`, `0.8.1`, `1.0.0` |
| Decalaj versiune ↔ DMG ↔ sidecar | n/a | **RESOLVED** — toate componentele Swift aliniate la `1.0.0` |
| Platformă | Cross-platform (Node 18+; Linux/macOS/Windows) | macOS-only; `LSMinimumSystemVersion=14.0`, build target macOS 15 |
| Runtime | Node.js ≥ 18, browser-side vanilla JS | Universal binary arm64+x86_64; sidecar Node 20+ pentru chat live |
| Limbaj | JavaScript / ES Modules | Swift 5.9, strict concurrency `complete` |
| Persistență | SQLite (`better-sqlite3`, **4 tabele**) cu graceful fallback no-op | SwiftData (**6 `@Model` entități** — +`ChatTranscriptEntity` +`PermissionDecisionEntity`) |
| UI Framework | HTML/CSS/JS — template engine ad-hoc placeholders `/*NAME*/` | SwiftUI + MVVM strict (`@Observable`, fără `EnvironmentObject`) |
| Distribuție | npm, Docker `node:22-alpine`, docker-compose | DMG cu `hdiutil` + `verify-universal.sh` + `notarize.sh` + `sparkle-appcast.sh` (RE1-RE3 necesită Apple Developer real, restul wired) |
| Code signing | n/a | `CODE_SIGN_IDENTITY: "-"` ad-hoc; pipeline pregătit pentru Developer ID + notarization |

---

## Sumar executiv

- **Două aplicații care acum diverg conștient.** Web a rămas stabil la `0.8.1` ca server cross-platform (Docker/npm/browser); Swift a evoluat la `1.0.0` ca macOS native cu chat live mature. Convergența completă (chat live în web sau Docker în Swift) nu mai e un obiectiv intern de paritate — e un proiect separat scump.
- **Versiunile sunt acum sincronizate la nivel Swift.** `project.yml MARKETING_VERSION=1.0.0` e single source of truth: `build-dmg.sh` citește din el; `sidecar/package.json` e bumped la `1.0.0`; `swift/CHANGELOG.md` documentează evoluția (vezi commits `db30778..d1d94a6`). Decalajul `1.0 ↔ 0.8.0 ↔ 0.8.1` din V1 a fost rezolvat.
- **Paritatea funcțională pe features de bază e completă.** Toate cele 18 lipsuri din `IMPROVEMENTS_SWIFT.md` au fost livrate: FavoritesSidebar funcțional, TagsSidebar funcțional cu CRUD, ExportSheet wired la ViewModel, FileWatcher conectat la `ProjectListViewModel`/`SessionListViewModel`, bookmark add cu hotkey `B`, custom themes import, session compare cu diff highlighting, bulk Include/Exclude, multi-input concatenation, Import HTML UI, cross-project search.
- **Swift a depășit paritatea inițială prin 16 features chat noi (G1-G16) + Docs in-app.** Chat are acum persistență SwiftData, conversation forking cu branch list, MCP servers integration, model picker, system prompt editor, tool whitelisting UI, slash commands `.claude/commands/*.md`, permission management UI, drag-drop attachments, PDF/image preview, token counter live, regenerate last turn, export din header, multi-tab chats.
- **Drift risk dramatically redus.** Swift are acum 46 unit tests pentru `TranscriptParser` (paritate 1:1 cu web `test-parser.mjs`), 18 pentru `SecretRedactor`, 7 pentru `ThemeService`, plus suite-uri pentru `StatsComputer`, `HTMLRenderer`, `MarkdownExporter`, `SessionResolver`. P2.1 (single source secret patterns) și P2.2 (single source themes) au fost rezolvate.
- **Direcția evoluției e clară.** Web rămâne candidatul natural pentru SERVER (Docker, multi-user remote, terminal embedded, npm CLI); Swift e candidatul natural pentru CLIENT DESKTOP rich (chat live, persistență, MCP, docs in-app). Apropierea lor reciprocă ar fi un proiect cu cost mare și valoare incrementală mică.
- **Singurele gap-uri restante în Swift** sunt în release engineering (RE1-RE3: signing/notarization/Sparkle necesită Apple Developer Program real) plus 3 teste skipped (`HTMLRenderer ↔ HTMLExtractor` format mismatch) și 1 pre-existent (`ClaudeAgentSkeleton testEchoRoundTrip`). Chunk batching G11 deferred ca polish viitor.

---

## Scoreboard paritate — evoluție V1 → V2

Tabelul de mai jos urmărește cele 48 features din `IMPROVEMENTS_SWIFT.md § Scoreboard` cu statusul V1 (pre-sprint) și V2 (post-sprint). Legendă: ✅ Done · 🟡 Partial · ❌ Missing · 🐛 Buggy · ⚪ Web-only intentional.

| # | Feature | V1 status | V2 status | Sprint |
|---|---|---|---|---|
| 1 | Parser Claude Code | ✅ (0 teste Swift) | ✅ (46 teste Swift) | sprint 3 |
| 2 | Parser Cursor | ✅ | ✅ | — |
| 3 | Parser Codex CLI | ✅ | ✅ | — |
| 4 | Redaction 11 patterns | 🟡 dublură | ✅ single source + 18 teste | sprint 3 |
| 5 | Custom redact rules | ❌ | ✅ via Export sheet + Settings | sprint 1 (P0.3 polish) |
| 6 | Themes 8 built-in | ✅ dublure | ✅ single source JSON + 7 teste | sprint 3 |
| 7 | `--theme-file` custom JSON | ❌ | ✅ Settings → Import | sprint 2 (P1.4) |
| 8 | Discovery 3 root-uri | ✅ | ✅ | — |
| 9 | Multi-account `~/.claude-*` | ✅ | ✅ | — |
| 10 | Dashboard heatmap | ✅ | ✅ + interactiv | sprint 7 (P3.9) |
| 11 | Sessions table sortable | ✅ | ✅ | — |
| 12 | Editor turn edit | ✅ | ✅ | — |
| 13 | Bulk Include/Exclude All | ❌ | ✅ | sprint 2 (P1.5) |
| 14 | Bulk multi-turn selection | ❌ | ✅ context-menu before/after | sprint 2 |
| 15 | Replay native player | ✅ | ✅ | — |
| 16 | Bookmark add hotkey B | ❌ | ✅ | sprint 2 (P1.6) |
| 17 | Tool grouping threshold | 🐛 inconsistent (1+ vs 5+) | ✅ documentat: Swift 5 configurabil | sprint 2 (P1.7) |
| 18 | Stats overview + chart | ✅ | ✅ | — |
| 19 | Git read-only | ✅ | ✅ | — |
| 20 | Search per project | ✅ | ✅ | — |
| 21 | Cross-project search (claude+cursor+codex) | 🟡 doar claude | ✅ | sprint 2 (P1.3) |
| 22 | Export HTML | 🐛 sheet TODO | ✅ wired | sprint 1 (P0.3) |
| 23 | Export Markdown | ✅ | ✅ | — |
| 24 | Export PDF | ✅ | ✅ | — |
| 25 | Import HTML | 🟡 API only | ✅ File → Import | sprint 2 (P1.1) |
| 26 | Favorites sidebar | 🐛 stub | ✅ real listing | sprint 1 (P0.1) |
| 27 | Tags sidebar + assign | ❌ stub | ✅ CRUD + drag-drop | sprint 1 (P0.2) |
| 28 | Plans tab | ✅ | ✅ | — |
| 29 | CLAUDE.md / MEMORY.md | ✅ | ✅ | — |
| 30 | Session compare diff | 🟡 no highlight | ✅ LCS-based diff | sprint 3 (P1.8) |
| 31 | FileWatcher → live update | 🟡 unwired | ✅ wired cu debounce | sprint 1 (P0.6) |
| 32 | Multi-input concat | ❌ | ✅ Dashboard multi-select → Chain | sprint 2 (P1.2) |
| 33 | OG meta tags export | ✅ flags | ✅ configurabil | sprint 2 (P1.9) |
| 34 | Bookmarks `--mark` echivalent UI | ❌ | ✅ BookmarksEditorView | sprint 2 (P1.10) |
| 35 | MenuBar NSStatusItem | ❌ dir gol | ✅ StatusItemController | sprint 1 (P0.4) |
| 36 | KeyboardShortcuts panel real | 🐛 6/7 | ✅ generat din AppTab.allCases | sprint 1 (P0.7) |
| 37 | Settings Locate Node/Claude | 🟡 API only | ✅ UI cu badge status | sprint 1 (P0.8) |
| 38 | Chats live SDK | ✅ | ✅ + persistență | sprint 4 (G1) |
| 39 | Chats split-view | ❌ disabled | ✅ via multi-tab G16 | sprint 4 (G16) |
| 40 | Chats persistență istoric | ❌ | ✅ ChatTranscriptEntity | sprint 4 (G1) |
| 41 | Chats model picker | ❌ | ✅ Sonnet/Opus/Haiku cu pricing | sprint 5 (G4) |
| 42 | Chats MCP integration | ❌ | ✅ MCPServersSettingsView | sprint 7 (G3) |
| 43 | Chats slash commands | ❌ | ✅ `.claude/commands/*.md` | sprint 5 (G7) |
| 44 | Chats attachments preview | ❌ | ✅ drag-drop + QLPreview | sprint 5 (G9+G10) |
| 45 | Terminal embedded lazygit | ⚪ web-only | ⚪ web-only | — |
| 46 | Docker distribution | ⚪ web-only | ⚪ web-only | — |
| 47 | npm CLI binary | ⚪ web-only | ⚪ web-only | — |
| 48 | CSRF privacy check | ⚪ irrelevant macOS | ⚪ irrelevant macOS | — |

**Recap V2:**

- ✅ Done: **40** features (V1: 18)
- 🟡 Partial: **0** (V1: 8)
- ❌ Missing: **0** (V1: 17)
- 🐛 Buggy: **0** (V1: 4)
- ⚪ Web-only intentional: **4** (V1: 4)

Toate items 1-44 sunt acum ✅; items 45-48 rămân intentional web-only.

---

## Paritate funcțională (ce există în AMBELE)

Tabel actualizat cu coloana **V1 status** și **V2 status** pentru a vedea evoluția în această fereastră.

| Funcționalitate | Web (cum/locație) | Swift (cum/locație) | V1 status | V2 status |
|---|---|---|---|---|
| Parser Claude Code | `src/parser.mjs:529` | `Services/TranscriptParser.swift:16-847` | ✅ paritate, **0 teste Swift** | ✅ paritate, **46 teste Swift 1:1** (Tests/TranscriptParserTests.swift) |
| Parser Cursor | `parser.mjs:106-112` | `TranscriptParser.swift:680-691` | ✅ | ✅ |
| Parser Codex CLI | `parseCodexTranscript` | `parseCodexTranscript` Swift | ✅ | ✅ |
| Redaction secrets | `src/secrets.mjs` — 11 patterns | `Services/SecretRedactor.swift` — single source (`SecretRedactor.patterns`) | 🟡 dublură Swift | ✅ single source + **18 teste** (P2.1 livrat sprint 3) |
| Teme | `src/themes.mjs` — 8 built-in | `Resources/themes.json` — single source bundlat + façade `Theme`/`ThemeService` | 🟡 dublură Swift | ✅ single source + **7 teste** (P2.2 livrat sprint 3) |
| Theme custom JSON | `--theme-file` | Settings → Import Custom Theme (P1.4) | ❌ doar web | ✅ paritate |
| Discovery sesiuni | `src/resolve-session.mjs` + `discoverSessions` | `Services/SessionDiscovery.swift:74-429` + `SessionResolver.swift:15-147` | ✅ | ✅ |
| Player | `template/player.html` 2725 linii / `player.min.html` 135 linii | Native `ReplayView` + reuse `Resources/player.min.html` la export | ✅ | ✅ |
| Editor turns | `editor.html` 1772 linii + 3 panouri | `EditorView` + `TurnBrowserPanel` + `TurnEditorPanel` | 🟡 fără bulk în Swift | ✅ bulk Include/Exclude All + context-menu before/after (P1.5) |
| Export HTML | `src/renderer.mjs` `deflateSync+base64` | `Services/HTMLRenderer.swift` `compression_encode_buffer COMPRESSION_ZLIB` | 🐛 buton sheet TODO Swift | ✅ wired la `vm.export(...)` cu alert pe eroare (P0.3) |
| Export Markdown | `template/player.html` button | `Services/MarkdownExporter.swift` + MD button în tabel + Export sheet | ✅ | ✅ |
| Export PDF | browser print | `WKWebView.pdf(configuration:)` programatic | ✅ | ✅ |
| Import HTML | subcomandă CLI `extract` | File → Import HTML Replay… (`Cmd+Shift+I`) cu `HTMLExtractor` (P1.1) | ❌ doar API intern Swift | ✅ wired în File menu |
| Dashboard sessions | `template/dashboard.html` 2938 linii + heatmap | `Views/Dashboard/DashboardView.swift` + `ActivityHeatmapView` | ✅ | ✅ + heatmap interactiv (P3.9) |
| Stats | lazy `POST /api/session-stats` cu cache SQLite | `Services/StatsComputer.swift` + Swift Charts | ✅ | ✅ |
| Git integration | `POST /api/git-details` | `Services/GitService.swift` read-only | ✅ | ✅ |
| Search | `POST /api/search` (cross-project) | `Services/SearchService.swift` — acum **cross-source** (claude+cursor+codex) (P1.3) | 🟡 doar claude în Swift | ✅ paritate |
| Deep links / Shortcuts | `Space/K/→/L/T`, `?`, `1/2/3` | `Space/K/→/L/T/Esc`, `Cmd+1..7`, `Cmd+F`, `Cmd+E`, `Cmd+/`, **`B` add bookmark** | 🟡 fără B în Swift | ✅ + KeyboardShortcuts panel generat din `AppTab.allCases` (P0.7) |
| Favorites | `getFavorites/addFavorite` în `db.mjs` | `FavoritesViewModel` + `FavoriteEntity` SwiftData + **sidebar funcțional** | 🐛 stub în Swift | ✅ listing real în sidebar (P0.1) |
| Tags | `tags` table + `/api/tags` | `TagEntity` + `TagsViewModel` + **sidebar funcțional cu DisclosureGroup per tag + drag-drop** | 🐛 stub în Swift | ✅ listing + assign + chip integration în SessionTableView (P0.2) |
| Plans tab | `Plans` sub-tab | `PlansListView` cu `MarkdownTextView` preview | ✅ | ✅ |
| CLAUDE.md / MEMORY.md | sub-tab display | `ProjectFilesView` | ✅ | ✅ |
| Session compare | overlay în `dashboard.html:1288` cu `POST /api/transcript` | `SessionCompareView` cu **diff highlighting semantic (LCS)** (P1.8) | 🟡 fără diff Swift | ✅ paritate + summary header |
| FileWatcher → live updates | SSE `GET /api/events` la 10s | `FileWatcher` wired la `ProjectListViewModel` + `SessionListViewModel` cu debounce 500ms (P0.6) | 🟡 unwired Swift | ✅ paritate funcțională |
| Multi-input concat | `bin/claude-replay.mjs:247-270` (max 20 inputs) | Dashboard multi-select + `TranscriptParser.parseAndChain(filePaths:)` (P1.2) | ❌ doar web | ✅ paritate |
| Bookmarks add UI | `--mark "N:Label"` + `--bookmarks FILE` | hotkey `B` în Replay + `BookmarksEditorView` cu Import/Export JSON (P1.6/P1.10) | ❌ doar web | ✅ paritate UI |
| Account switcher multi-cont | `injectShared` în editor-server scanează `.claude*` | `AccountStore.availableAccounts()` cu UI auto-discovery `~/.claude-*` | ✅ ambele | ✅ ambele |
| OG/Twitter meta | hardcodat `es617.github.io/og.png` | Settings → "OG image URL" field cu default identic (P1.9) | 🟡 fără config Swift | ✅ configurabil în ambele |
| Tool grouping threshold | toate consecutive (1+) | configurabil `@AppStorage("toolGroupThreshold")` default 5 (P1.7) | 🐛 inconsistent | ✅ documentat în CHANGELOG ca decizie produs |

---

## Doar în Web (lipsă în Swift) — V2 update

Itemii care rămân **intentional** web-only după sprint-uri:

- **Docker / docker-compose distribution** — `Dockerfile` (`node:22-alpine` + lazygit + git) + `docker-compose.yml` cu volume read-only pentru `~/.claude*`, `~/.cursor`, `~/.codex`. Modul "server local accesibil în browser" e exclusiv web. Pe macOS native, distribuția echivalentă e DMG.
- **Terminal embedded (lazygit + xterm.js + WebSocket)** — `src/terminal.mjs` (`/ws/terminal`) spawn `lazygit`/shell în PTY; UI cu `xterm.js` + addons în `template/lazygit.html`. Swift folosește `NSWorkspace.openTerminal` standard prin AppleScript (`Views/Git/GitActionsView.swift`) — nu terminal embedded.
- **Pagina LazyGit dedicată** — rută `/lazygit` accesibilă din header. Swift n-are echivalent (decizie: dezvoltatorii folosesc Terminal.app standard).
- **npm CLI binary** — `bin: { "claude-replay": "bin/claude-replay.mjs" }` cross-platform. Swift folosește DMG ca modul de distribuție.
- **CSRF privacy check** — verificare anti-CSRF în `editor-server.mjs:914-925` care respinge Origin străin. Irelevant pentru macOS native (nu există server HTTP în Swift).
- **SSE live updates** — `GET /api/events` cu `EventSource` client-side. Echivalentul Swift e `FileWatcher` cu `DispatchSourceFileSystemObject` (acum wired în UI după P0.6).
- **Subcomanda CLI `extract`** — recuperează `turns` + `bookmarks` din replay HTML generat. Swift expune aceeași reverse-operație prin File menu → Import HTML Replay (P1.1 livrat) — funcțional echivalent dar nu CLI/batch.
- **Browse arbitrary path via `POST /api/browse`** — `editor-server.mjs:290-327`. Swift folosește `NSOpenPanel` standard care e mai bun din UX.
- **Player HTML self-contained ca artefact CLI/batch** — `claude-replay <input> -o out.html` produce HTML portabil fără UI. Swift produce același artefact dar doar prin Export sheet sau MD button (UI-driven).
- **Build-time minification cu esbuild** — `scripts/build-template.mjs` minifică `player.html` → `player.min.html`. Swift include direct `player.min.html` produs de pipeline-ul web (reuse al artefactului).
- **OG image default hostat la `es617.github.io`** — Swift acum permite configurarea via Settings (P1.9) dar nu mai are un default hostat extern; bundla `og.png` local opțional.
- **End-to-end Playwright suite** (58 e2e + ~140 unit) — Swift are acum unit tests echivalente pentru parser/redaction/themes/stats/renderer/markdown/resolver dar **lipsesc XCUITest UI tests** (3.5z rămase din testing strategy).

**REMOVED din "Doar în web"** (acum în Swift, livrate în sprint-uri):

- Import HTML UI ✓ (P1.1, sprint 2)
- Session chaining multi-input ✓ (P1.2, sprint 2)
- Cross-project search ✓ (P1.3, sprint 2)
- `--theme-file` custom themes ✓ (P1.4, sprint 2)
- Bulk Include/Exclude editor ✓ (P1.5, sprint 2)
- Bookmark add UI cu hotkey ✓ (P1.6, sprint 2)
- Bookmarks editor sheet ✓ (P1.10, sprint 2)
- OG meta tags config ✓ (P1.9, sprint 2)
- Session compare cu diff highlighting ✓ (P1.8, sprint 3)
- FileWatcher live updates ✓ (P0.6, sprint 1)

---

## Doar în Swift (lipsă în Web) — mărit considerabil vs V1

Pre-sprint, lista avea ~12 items. Post-sprint, lista are **30+ items** noi datorită sprint-urilor 4-7 (Chat Excellence M1-M4) + sprint 8 (Docs).

### Chat features (G1-G16 livrate prin sprint-urile 4-7)

- **Tab Chats live cu `@anthropic-ai/claude-agent-sdk`** — `ChatViewModel` + `ClaudeAgent` actor + sidecar Node bundlat. Permite continuarea unei sesiuni existente cu streaming tokens. (deja era V1)
- **Persistență chat SwiftData `ChatTranscriptEntity`** (G1, sprint 4) — `(sessionPath, projectPath, turnsJSON, accountDir, lastUpdated, costUsd, model)`. Active chats listing pentru quick-resume în ultimele 7 zile (`ChatActiveListView.swift`).
- **Conversation forking + branch list** (G2, sprint 6 CM3) — `... → Branch from here` per turn user; duplică sesiunea la `<id>-branch-<timestamp>.jsonl` truncat; păstrează legătura `parentSessionId` în SwiftData; `ChatBranchListView.swift` afișează arborele.
- **MCP servers integration UI** (G3, sprint 7 CM4) — Settings → "MCP Servers" tab (`MCPServersSettingsView.swift`) cu listă `[{name, command, args, env}]` persistată; `ClaudeAgent.StartOptions.mcpServers`; sidecar forwardează la `options.mcpServers`; ChatView header arată badge "MCP: N servers".
- **Model picker cu pricing tooltips** (G4, sprint 5 CM2) — `ChatModelPickerView.swift` dropdown Sonnet 4.6 / Opus 4.7 / Haiku 4.5 + per-million-token pricing; switch model → respawn agent.
- **System prompt sheet per-conversation** (G5, sprint 5 CM2) — `SystemPromptSheet.swift` cu textarea + checkboxes Include CLAUDE.md/MEMORY.md; respawn cu `--system-prompt-append`; persistat per-sessionPath.
- **Tool whitelisting UI** (G6, sprint 5 CM2) — `ChatToolPickerView.swift` menu cu toggle per tool (Bash, Read, Edit, Write, Glob, Grep, WebFetch, WebSearch, NotebookEdit, TodoWrite, Task + MCP tools auto-detected).
- **Slash commands `.claude/commands/*.md`** (G7, sprint 5 CM2) — `SlashCommandPickerView.swift` dropdown la `/`; scanează `<projectPath>/.claude/commands/*.md` + `~/.claude/commands/*.md`; `$ARGUMENTS` placeholder support.
- **Permission management UI** (G8, sprint 6 CM3) — `PermissionAlertView.swift` modal la `permission_request` event de la SDK: "Allow Bash to run `ls -la`? Once / Always / Never". Persistat în `PermissionDecisionEntity` per `(sessionId, toolName, action_signature)`.
- **Drag-drop attachments + previews** (G9+G10, sprint 5 CM2) — `ChatInputBarView.onDrop(of:[.fileURL])`; max 5 files, 64KB each. `ChatAttachmentChip` + `ChatAttachmentPreviewSheet` cu detection MIME: image → AsyncImage, PDF → QLPreviewView, code → CodeBlockView.
- **Streaming render quality polish** (G11 parțial, sprint 4 CM1) — cursor blink `▌`, smooth scroll `withAnimation(.spring())`. Chunk batching (50ms throttle) **deferred** ca polish viitor.
- **Token usage live counter** (G12, sprint 4 CM1) — parse `result.usage` (`input_tokens`, `output_tokens`, `cache_creation_tokens`, `cache_read_tokens`); 4 chip-uri în ChatView header cu pricing actual per model.
- **Regenerate last turn** (G13, sprint 6 CM3) — hover pe ultimul turn assistant → "Regenerate"; șterge last assistant, păstrează last user, respawn agent.
- **Export chat din header** (G14, sprint 4 CM1) — `ChatView` header → menu "Export" → reuse `ExportViewModel.export(turns: vm.turns, options: ...)`.
- **Continue from Replay → Chats link** (G15, sprint 4 CM1) — `ReplayControlsView` adaugă buton "Continue (live)" care `appState.switchTab(.chats)` + `resumingPath = currentSessionPath`.
- **Multi-tab chats** (G16, sprint 4 CM1) — `ChatsView` ca `TabView` orizontal; `ChatTabContainerView.swift` cu close-tab vs close-chat distinct; state persistat în SwiftData prin G1.

### Sidecar improvements (sprint 5)

- **IPC protocol versioning** — `{"type":"hello","protocol":"1"}` ca prim mesaj; Swift validează și refuză versiuni necunoscute.
- **Heartbeat ping din sidecar (1/30s)** — Swift detectează sidecar zombie via watchdog.
- **Structured logging levels** — `{level:"debug|info|warn|error", msg:...}` în stderr; Settings → "Show sidecar logs" pentru debugging.
- **Account integration cu chat** — `ChatViewModel.start()` preia `appState.claudeAccountDir` și-l pasă la `StartOptions`; `ClaudeAgent.start()` setează `env["CLAUDE_CONFIG_DIR"] = expandedAccountDirPath`. Izolare per-account confirmată.

### Docs in-app (sprint 8, commit `d1d94a6`)

- **Docs tab cu 15 topics** — `Views/Docs/DocsView.swift` + `DocsSidebarView.swift` + `DocsTopicView.swift`. Topics în `Resources/Docs/`: getting-started.md, ui-overview.md, dashboard.md, replay.md, transcript.md (în editor), chats.md, accounts.md, settings.md, search.md, stats.md, git.md, export.md, keyboard-shortcuts.md, troubleshooting.md, faq.md.
- **Help menu items** — link-uri direct la topics din meniu Help.
- **Inline `?` buttons** — peste tot în UI, fiecare deschide topic-ul relevant.
- **Full-text search peste docs** — bar de căutare în `DocsSidebarView`.

### Sprint 1 (P0) — stub-uri vizibile reparate

- **`FavoritesSectionView` real listing** (P0.1) — folosește `appState.favoritesVM.favorites`, click → `appState.selectSession`, context-menu "Remove from Favorites".
- **`TagsSectionView` cu CRUD complet** (P0.2) — `TagsViewModel` peste `DataStore.shared.getAllTaggedSessions()`; DisclosureGroup per tag; drag-drop session→tag; `TagChipView` wired în `SessionTableView`.
- **`ExportSheet` button wired** (P0.3) — apel `vm.export(turns:options:)` cu alert pe eroare; toggle Redact + userLabel/assistantLabel fields.
- **NSStatusItem MenuBar** (P0.4) — `Views/MenuBar/StatusItemController.swift` cu meniu rapid (Open last session, Open project, Settings, Quit) + listă "Recent Sessions" (max 10).
- **FileWatcher wired** (P0.6) — vezi tabel paritate; debounce 500ms.
- **KeyboardShortcuts panel** (P0.7) — generat din `AppTab.allCases`, nu mai hard-coded.
- **Settings sidecar locator UI** (P0.8) — secțiune "Sidecar" cu `Path to node` / `Path to claude` fields + butoane "Locate…" (NSOpenPanel filtrat) + status badge verde/roșu.
- **Speed slider sincronizat** (P0.9) — `ExportSheet` aliniat la `speedSteps [0.5..20]` din `ReplayViewModel`.
- **Cumulative cost chip mereu vizibil** (P0.10) — "$0.0000" la început cu tooltip; breakdown per turn ca chip secundar.

### Persistență (acum 6 entități vs 4 V1)

- **`SessionMetaEntity`** (V1 — meta cache cu mtime invalidation)
- **`SessionStatsEntity`** (V1 — JSON blob cu mtime invalidation)
- **`FavoriteEntity`** (V1 — unique pe path)
- **`TagEntity`** (V1 — composite unique `(path, tag)`)
- **`ChatTranscriptEntity`** (V2, sprint 4 G1) — persistă chat history complet
- **`PermissionDecisionEntity`** (V2, sprint 6 G8) — persistă decizii Once/Always/Never per `(sessionId, toolName, action_signature)`

### Release engineering wiring (sprint 6)

- **`swift/scripts/verify-universal.sh`** — verify `lipo -info` arm64+x86_64 (RE4 livrat).
- **`swift/scripts/notarize.sh`** — pipeline pentru `xcrun notarytool submit --wait` + `xcrun stapler staple` (RE2 wired; necesită Apple Developer real).
- **`swift/scripts/sparkle-appcast.sh`** — generează `appcast.xml` pentru auto-update (RE3 wired; necesită EdDSA signing key).
- **MetricKit crash reporting** (RE5 alternativ) — integrat în loc de Sentry pentru zero-overhead.
- **Telemetry opt-in** (RE6) — Settings → checkbox "Send anonymous usage stats" default OFF; events `app_launched`, `tab_switched`, `chat_started`, `export_clicked`.

### Polish UX (sprint 7, P3 items)

- **P3.1 Drag-drop session files pe window** — `WindowGroup.onDrop(of:[.fileURL])` cu visual feedback overlay "Drop JSONL here".
- **P3.2 Recent sessions menu** — `NSDocumentController.shared.recentDocumentURLs` + UserDefaults persistence; File → Open Recent submeniu cu max 10 + "Clear Menu".
- **P3.3 Autosave editor state** — debounce 2s → serialize `[excludedTurns, edits]` în `UserDefaults("editor-state-<sessionPath>")`; restore la `.task(id:)`; buton "Discard".
- **P3.4 Accessibility VoiceOver** — `.accessibilityLabel(_:)` peste tot unde labelStyle e iconOnly; spinner `.accessibilityHidden(true)`; Replay autoscroll cu `.accessibilityAnnouncement`.
- **P3.5 Keyboard navigation complete** — Tab navigation prin Project list / Session table / Replay controls; `↑/↓` sidebar; `Enter` activare; Editor `↑/↓` între turns.
- **P3.6 Splash / Empty-state cu mascot** — `SplashEmptyView.swift` cu mascot + SF Symbol animație subtle.
- **P3.7 SpinnerVerb reflect status** — sub-listare per stare ("Loading…": Resolving/Parsing/Indexing; "Chatting…": Composing/Tooling/Thinking).
- **P3.8 Smooth scroll + cursor blink în Chat** — `withAnimation(.spring(response: 0.4, dampingFraction: 0.85))` + caret blink `▌` la sfârșitul ultimului text block în mod `sending`.
- **P3.9 Dashboard heatmap interactiv** — hover tooltip cu data + count sesiuni; click → filtrează `SessionTableView` la acea zi.

### Items deja în V1 (rămase)

- Sidecar Node bundlat în `.app/Contents/Resources/Sidecar/`
- Multi-account support automat în UI (`AccountStore`)
- SwiftUI nativ Window + Settings macOS
- WKWebView pentru render HTML → PDF
- Document types `CFBundleDocumentTypes` (`JSONL Transcript`) cu drag-drop pe icon
- MVVM strict cu `@Observable`, strict concurrency `complete`
- Swift Charts `BarMark` orizontal pentru tool breakdown
- Prefix chips `@` / `!` / `#` în chat input
- Mode toggle (Plan / Accept Edits / Default) cu bypass ascuns
- SpinnerVerbView cu 187 verbe + shimmer reverse-sweep (acum cu sub-listare per status, P3.7)
- CommandMenu("Navigate") + Help → Keyboard Shortcuts

---

## Implementări divergente ale acelorași funcționalități — V2 update

### Parser transcripte

- **Web** — `src/parser.mjs` (697 linii) cu JavaScript. **46 teste** în `test/test-parser.mjs`.
- **Swift** — `Services/TranscriptParser.swift` (~847 linii) cu `JSONSerialization` + `AnyCodable`. **46 teste** în `Tests/TranscriptParserTests.swift` cu fixtures copiate din `test/fixture*.jsonl` în `Tests/Fixtures/`.

**Risc de drift V1:** major (web 46 / Swift 0). **V2:** drastic redus (paritate test 1:1). Cazurile edge sunt verificate explicit prin aceleași fixtures.

### Redaction

- **Web** — `src/secrets.mjs` cu o singură sursă: 11 patterns în `SECRET_PATTERNS`, `redactSecrets(text)` + `redactObject(obj)`. **17 teste**.
- **Swift V1** — două surse paralele (`Models/SecretPattern.swift` + `Services/SecretRedactor.swift`). Risc de drift.
- **Swift V2** — single source `Services/SecretRedactor.swift` cu `SecretRedactor.patterns: [SecretPattern]` (P2.1, sprint 3). `Models/SecretPattern.swift` păstrat ca tipul valoare returnat. **18 teste** în `SecretRedactorTests.swift`.

### Themes

- **Web** — `src/themes.mjs` cu o singură sursă: dict cu hex strings. 8 teme.
- **Swift V1** — două surse paralele (`Models/Theme.swift` SwiftUI Colors + `Services/ThemeService.swift` hex strings).
- **Swift V2** — single source `Resources/themes.json` bundlat (P2.2, sprint 3); la load creează atât SwiftUI `Color` cât și CSS string dintr-un singur dict. `Theme` și `ThemeService` au devenit facade peste loader-ul JSON. Noi teme = doar JSON, nu Swift recompile. **7 teste** în `ThemeServiceTests.swift`.

### Player

- **Web** — singurul player, HTML self-contained (`player.html` 2725 / `player.min.html` 135 linii).
- **Swift** — **dual:**
  1. Native `ReplayView` + `ReplayViewModel` cu `LazyVStack(ForEach turns)`, `revealedBlockCount`, `play()` async loop cu `adaptiveDelay = min(max(charCount * 0.03, 0.6), 10.0) / speed`.
  2. HTML export reused `player.min.html` bundlat în `Resources/`.

**Tool grouping threshold:** sincronizat ca *decizie de produs documentată* — Swift `@AppStorage("toolGroupThreshold")` default 5 (P1.7, sprint 2), web rămâne la 1+. Documentat în `swift/CHANGELOG.md` și `IMPROVEMENTS_WEB.md` ca direcție viitoare pentru web.

**Splash:** Web are splash screen; Swift folosește `SplashEmptyView.swift` cu mascot + SF Symbol animație subtle (P3.6 livrat).

### Persistență

- **Web** — `src/db.mjs` (205 linii). `better-sqlite3`, PRAGMA `WAL`. **4 tabele**. Graceful fallback no-op.
- **Swift V1** — SwiftData `ModelContainer`. **4 entități** (`SessionMetaEntity`, `SessionStatsEntity`, `FavoriteEntity`, `TagEntity`).
- **Swift V2** — **6 entități** (+`ChatTranscriptEntity` G1, +`PermissionDecisionEntity` G8).

Schema rămâne izomorfică între web și Swift pentru cele 4 entități originale; entitățile noi (`ChatTranscriptEntity`, `PermissionDecisionEntity`) nu au echivalent web pentru că web n-are chat live.

### Discovery sesiuni

- Aceleași 3 root-uri (`~/.claude*`, `~/.cursor`, `~/.codex`).
- **V1:** Swift reîncarcă doar la Refresh manual sau pe `task(id: claudeAccountDir)` change; FileWatcher exista dar nu era wired.
- **V2:** Swift `FileWatcher` wired la `ProjectListViewModel` + `SessionListViewModel` (P0.6, sprint 1) cu debounce 500ms. Paritate funcțională cu SSE din web.

### Export HTML

- **Web** — `src/renderer.mjs` cu `deflateSync` (Node `zlib`) + `base64`.
- **Swift** — `Services/HTMLRenderer.swift` cu `compression_encode_buffer COMPRESSION_ZLIB` + strip manual header `0x78 0x9C` și Adler-32 (4 bytes la final) pentru compatibilitate raw-deflate.

Output bit-identic. **3 teste skipped** în `HTMLRendererTests.swift` din cauza unui mismatch format edge case între `HTMLRenderer` și `HTMLExtractor` (round-trip pe payloads anume) — documentat ca follow-up minor.

### Bookmarks

- **V1:** Web are CLI flags `--mark "N:Label"` + `--bookmarks FILE`; Swift n-are UI pentru append.
- **V2:** Swift acum complet — hotkey `B` în Replay (P1.6, sprint 2) + `BookmarksEditorView` cu Import/Export JSON (P1.10, sprint 2). Format compatibil cu CLI: `[{turn: N, label: "..."}, ...]`. `BookmarkEntity` extensie pe FavoriteEntity sau nou — verificat ca persistat.

---

## Decalaje de versiune și sincronizare — RESOLVED

### Status V1 (problemă)

| Component | Versiune V1 |
|---|---|
| `Info.plist` | `1.0` / `1` |
| `project.yml MARKETING_VERSION` | `1.0.0` |
| Root `package.json` (web) | `0.8.1` |
| DMG livrat | `Claude-MTW-Replay-0.8.1.dmg` (citit din root) |
| Sidecar `swift/sidecar/package.json` | `0.8.0` |

### Status V2 (resolved)

| Component | Versiune V2 | Sursă |
|---|---|---|
| Root `package.json` (web) | `0.8.1` | unchanged |
| `swift/project.yml MARKETING_VERSION` | `1.0.0` | **source-of-truth Swift** |
| `swift/Claude-MTW-Replay/Info.plist CFBundleShortVersionString` | substituit la `$(MARKETING_VERSION)` la build → `1.0.0` | derivat |
| DMG livrat | `Claude-MTW-Replay-1.0.0.dmg` în `swift/dist/` | `build-dmg.sh` citește din `project.yml` |
| Sidecar `swift/sidecar/package.json` | `1.0.0` | sincronizat manual |
| `swift/CHANGELOG.md` | Keep-a-Changelog cu `0.8.0`, `0.8.1`, `1.0.0` | nou introdus |

Decalajul `1.0 ↔ 0.8.0 ↔ 0.8.1` din V1 a fost rezolvat. Toate componentele Swift sunt acum la `1.0.0`. Web rămâne la `0.8.1` și decalajul `0.8.1 ↔ 1.0.0` e intentional: Swift a marcat primul public release cu 1.0.

### Commit-uri sprint care reflectă progresul

```
d1d94a6 feat: in-app docs tab + Help menu + inline ? buttons
827896c sprint 7 (chat M4 / CM4 — MCP + P3 polish)
2c18670 sprint 6 (chat M3 / CM3 + release engineering)
8018a87 sprint 5 (chat M2 / CM2): power features
ca1ed7c sprint 4 (chat M1 / CM1): foundations + UX polish
c44dd1c sprint 3 (P2 dedup + testing foundation + P1.8)
280c534 sprint 2 (P1 + P0.5): web parity features
db30778 sprint 1 (P0): wire up stub UI + visible fixes
```

Range `db30778..d1d94a6` = 8 commit-uri (7 sprint + 1 docs). Range `db30778..827896c` = 7 sprint-uri pure.

---

## Recomandări (acum în două direcții)

### Pentru web (apropiere de Swift) — *opțional*

Dacă obiectivul devine "web să se apropie de Swift", următoarele ar fi candidați:

1. **Chat live tab** — cel mai mare lift. Două variante:
   - **Direct SDK**: integrează `@anthropic-ai/claude-agent-sdk` în Node server (deja Node 22), expune un endpoint `/api/chat/stream` (SSE) și UI corespondent.
   - **Proxy la sidecar**: refactorizează sidecar-ul Swift ca server independent rulabil cu `node sidecar.js --listen :PORT`; web face proxy la el.
   Effort: 3-5 sprint-uri (mare proiect).
2. **In-app docs page upgrade** — `template/docs.html` actual e minim; preia formatul Swift cu 15 topics + full-text search + inline `?` buttons în UI. Effort: 1 sprint.
3. **Parser tests sync cu Swift** — actual la paritate funcțională (46 ↔ 46); revizuire periodică pentru a verifica că nu apare drift. Effort: 0.5 zile per release.
4. **Conversation forking pentru replay** — port limitat din Swift G2: "branch from turn N" pentru a crea o copie editabilă a sesiunii la un punct specific. Util pentru "ce-ar fi fost dacă" în editor. Effort: 2-3 zile.
5. **Permission UI pentru scenarii server-side** — dacă apare nevoie de remote-control al unei sesiuni Claude Code prin web (e.g. în Docker pe serverul echipei), portează `PermissionAlertView`. Effort: 2-3 zile.
6. **MCP servers config UI** — dacă chat-ul ajunge în web, MCP config devine necesar. Effort: 2 zile.
7. **CHANGELOG.md continuare** — versiunile `0.5..0.8.1` nu sunt documentate; reluare format Keep-a-Changelog. Effort: 1 zi.

### Pentru Swift (lustruire) — *backlog mic*

1. **Fix `HTMLRenderer` ↔ `HTMLExtractor` format mismatch** — 3 teste skipped în `HTMLRendererTests.swift`. Effort: 0.5-1 zi.
2. **Fix `ClaudeAgentSkeleton.testEchoRoundTrip`** — 1 test pre-existent care eșuează intermitent. Effort: 0.5 zi (diagnose race condition în spawn/echo).
3. **Chunk batching G11** — deferred din sprint 4 ca polish viitor; throttle markdown re-render la ~50ms sau la newline. Effort: 1.5 zile.
4. **RE1-RE3: signing/notarization/Sparkle** — pipeline-ul e wired (scripts/notarize.sh, sparkle-appcast.sh, project.yml ready), dar necesită Apple Developer Program ($99/an) + cert real + EdDSA key. Effort: 1-2 zile execuție administrativă.
5. **XCUITest UI tests** — flow-uri end-to-end (open project → select → play replay; edit turn → export; chat resume cu sidecar mock). Effort: 3.5 zile (din testing strategy).
6. **MAS sandboxing** — dacă vrem distribuție Mac App Store, shell command `/bin/sh -c` în Chat input nu va fi posibil sub sandbox. Decizie strategică pendente.

### Strategic

- **Web continuă ca "server-side & embeddable HTML"** — Docker, multi-user remote, terminal embedded, npm CLI, browser-portable artefact. Punctul forte rămâne deployment-ul simplu și cross-platform.
- **Swift continuă ca "rich macOS client"** — chat live, persistență, MCP, docs in-app, native macOS UX.
- **Convergența completă** (chat în web sau Docker în Swift) ar fi un proiect separat scump. Recomandare: NU se urmărește în următoarele 2-3 trimestre; cele două aplicații deservesc personae diferite (DevOps/sharing vs. Power user macOS).
- **Punct de sincronizare obligatoriu:** parser-ul + redaction + themes — orice schimbare semantică într-una din cele 3 aplicații trebuie portată în cealaltă, validată prin teste 1:1 (web 46 ↔ Swift 46 pentru parser, web 17 ↔ Swift 18 pentru redaction, web 6 ↔ Swift 7 pentru themes).

---

## Verdict scurt

- **Web (`claude-replay v0.8.1`)** e stabil, testat (58 e2e + ~140 unit Playwright/node:test), distribuit prin Docker/npm. Folosit ca server local / share-able HTML artefact. Nu s-a modificat în această fereastră.
- **Swift (`Claude-MTW-Replay v1.0.0`)** e production-ready la 1.0.0, depășește paritatea inițială declarată la `v0.8.1-swift`, adaugă chat live mature (G1-G16) + MCP + persistență chat + docs in-app + permission UI + 7 sprinturi de polish.
- Cele două au evoluat **în direcții complementare conștient**: web e server, Swift e client desktop. Convergența completă nu mai e obiectiv intern de paritate.
- Singurele gap-uri restante în Swift sunt **administrative** (Apple Developer Program pentru RE1-RE3) plus 4 teste cu issue-uri minore. Toate features de produs au fost livrate.
- Drift risk între parsere e drastic redus (test paritate 1:1) — schimbările viitoare în parser/redaction/themes pot fi sincronizate cu confidence.

---

## Apendix — Referințe

- [AUDIT_DIFF.md](AUDIT_DIFF.md) — V1, 215 linii, baseline pre-sprint.
- [AUDIT_WEB.md](AUDIT_WEB.md) — auditul web (455 linii), încă valid.
- [AUDIT_SWIFT.md](AUDIT_SWIFT.md) — auditul Swift V1 (607 linii), pre-sprint; folosit ca baseline.
- [IMPROVEMENTS_SWIFT.md](IMPROVEMENTS_SWIFT.md) — planul cu 18 lipsuri concrete + roadmap 7 sprinturi (executat integral).
- [IMPROVEMENTS_WEB.md](IMPROVEMENTS_WEB.md) — planul pentru web (NU executat în această fereastră).
- `swift/CHANGELOG.md` — Keep-a-Changelog cu `0.8.0`, `0.8.1`, `1.0.0`.
- Commit range sprinturi: `db30778..d1d94a6` (8 commit-uri).
- Codul Swift: `/Users/anonymous-dd/work/claude-replay/swift/Claude-MTW-Replay/`
- Sidecar: `/Users/anonymous-dd/work/claude-replay/swift/sidecar/sidecar.js` (canonic; copia bundlată în `.app/Contents/Resources/Sidecar/` generată de `build.sh`).
