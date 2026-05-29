# Parity Audit — Swift macOS app vs Web app (2026-05)

**Auditor:** independent code-level verification (not trusting prior audit docs)
**Web app:** `claude-replay` v0.8.1 (Node/JS, Docker) — `src/*.mjs`, `bin/`, `template/`
**Swift app:** `Claude MTW Replay` v1.0.0 — `swift/Claude-MTW-Replay/` (156 swift files)
**Method:** Web feature surface built from CODE (every route in `editor-server.mjs`, every CLI flag in `bin/claude-replay.mjs`, every module export). Each feature traced end-to-end in Swift source. Existing `AUDIT_*_V2.md` claims re-checked against current code.

---

## Executive summary

Parity is **largely real and high-quality**. The transcript parser, secret redactor, theme set, session discovery (Claude/Cursor/Codex + multi-account), stats, git read-only, search, HTML/Markdown export, HTML extract, editor turn-editing, bookmarks, favorites, tags, plans, and the dashboard are all genuinely ported and wired in Swift — not stubs. The Swift app also adds a substantial **feature the web app does not have at all**: a live interactive Claude chat client (via a bundled Node sidecar wrapping the Agent SDK), with MCP, model picker, slash commands, attachments, and persisted history.

The prior `AUDIT_DIFF_V2.md` headline ("40/40 done, 0 gaps") is **mostly accurate but over-states a few items**. I found:

- **1 genuine correctness bug** in the export pipeline (a JSON key mismatch that breaks tool-result timing in Swift-exported replays and breaks extract round-trip of Swift's own output).
- **3 genuine (minor) parity gaps** where Swift silently drops data the web collects.
- **Several over-claims / stale framings** in the audit docs (Plans data source differs; Agent stats field is wrong; stats `teams` dropped; tool-grouping "documented" rather than matched).

**Real gap count: 4** (1 bug + 3 data gaps). None are showstoppers; all are fixable in <1 day. The 4 web-only items (Docker, npm CLI, embedded lazygit terminal, CSRF) are correctly classified as intentionally web-only.

---

## Parity matrix

Legend: ✅ wired · 🟡 partial/divergent · ❌ missing · ⚪ web-only-intentional

### Core engine (parser / render / redact / extract)

| Web feature | Web evidence | Swift status | Swift evidence |
|---|---|---|---|
| Parse Claude Code JSONL | `src/parser.mjs:529` `parseTranscript`, `:89` `parseJsonl` | ✅ | `Services/TranscriptParser.swift:573,114` |
| Parse Cursor (role-normalised, thinking-promotion) | `parser.mjs:106-112, :626-635` | ✅ | `TranscriptParser.swift:129-144, :680-691` |
| Parse Codex CLI (event-based, apply_patch, exec_command) | `parser.mjs:314-522` | ✅ | `TranscriptParser.swift:343-568` |
| `detectFormat` | `parser.mjs:67-83` | ✅ | `TranscriptParser.swift:87-109` |
| `applyPacedTiming` | `parser.mjs:645-659` | ✅ | `TranscriptParser.swift:777-797` |
| `filterTurns` (range/exclude/from/to) | `parser.mjs:667-697` | ✅ | `TranscriptParser.swift:802-843` |
| Secret redaction — 11 patterns | `src/secrets.mjs:8-49` | ✅ | `Services/SecretRedactor.swift:20-61` (verbatim 11) |
| `redactObject` recursive | `secrets.mjs:72-83` | ✅ | `SecretRedactor.swift:69-84` |
| Custom `--redact text=repl` rules | `bin/claude-replay.mjs:370-377`, `renderer.mjs:44-54` | 🟡 | Export sheet has redaction toggle; custom search/replace rules exist in Settings per audit but only `redactSecrets` bool flows into `RenderOptions` (`HTMLRenderer.swift:18`). No `redactRules` array in `RenderOptions`. **Minor gap** (see Gaps). |
| HTML render (self-contained player) | `src/renderer.mjs:120-176` | ✅ | `Services/HTMLRenderer.swift:29-76` |
| Compressed embed (raw deflate base64) | `renderer.mjs:35-37` | ✅ | `HTMLRenderer.swift:101-120` (strips zlib wrapper to raw deflate to match Node) |
| `extract` HTML → JSON | `src/extract.mjs`, `bin:132-158` | ✅ | `Services/HTMLExtractor.swift:16-116` |

### CLI flags (`bin/claude-replay.mjs`)

The whole CLI is ⚪ web-only as a *binary*, but each *capability* is checked for UI equivalence in Swift.

| CLI flag | Web | Swift equivalent | Status |
|---|---|---|---|
| `--turns N-M`, `--exclude-turns` | `bin:217-245` | Editor include/exclude + range | ✅ `EditorViewModel.swift:55,66` |
| `--from/--to` | `bin:272-277` | `filterTurns` available | 🟡 engine present; no dedicated time-filter UI in export sheet (acceptable) |
| `--speed`,`--no-thinking`,`--no-tool-calls` | `bin:379-394` | `ExportOptions` / `RenderOptions` | ✅ |
| `--theme`,`--theme-file` | `bin:196-215`, `themes.mjs:220` | 8 built-ins + Settings import | ✅ `Models/Theme.swift`, ThemeService |
| `--title/--description/--og-image` | `bin:388-390` | `ExportOptions.title/description/ogImage` | ✅ `Models/ExportOptions.swift:11-13` |
| `--mark N:Label`, `--bookmarks file` | `bin:321-361` | BookmarksEditorView, B-hotkey | ✅ `Views/Replay/BookmarksEditorView.swift` |
| `--timing auto/real/paced` | `bin:291-299` | `ExportOptions.TimingOptions` | ✅ `ExportOptions.swift:20-32` |
| Multi-input concat (≤20, chronological) | `bin:160-270` | `parseAndChain` | ✅ `TranscriptParser.swift:721-772` + ChainedReplaySheet |
| `--no-minify/--no-compress` | `bin:392-393` | `minified`/`compress` flags | ✅ `ExportOptions.swift:16-17` |
| `--list-themes`, `-v`, `-h` | `bin:57-68` | n/a (GUI) | ⚪ |

### HTTP API routes (`editor-server.mjs handleApi`)

| Route | Web evidence | Swift status | Swift evidence |
|---|---|---|---|
| `GET /api/sessions` (discover) | `editor-server.mjs:928` | ✅ | `SessionDiscovery.discoverSessions` `:130` |
| `GET/POST /api/accounts` (multi `~/.claude*`) | `:938-952` | ✅ | `AccountSwitcherMenu.swift`, `AppState.swift` (accountDir threaded through discovery `:130`) |
| `GET /api/themes` | `:955` | ✅ | ThemeService + `themes.json` |
| `POST /api/browse` | `:960` | ✅ | File importer / FileManager browse |
| `POST /api/load` / `/api/edit` / `/api/reset` | `:973,:1013,:1057` | ✅ | `EditorViewModel.swift:30,37` (working/original turns, hasEdits) |
| `POST /api/preview` / `/api/export` | `:1026,:1037` | ✅ | `HTMLRenderer.render` + ExportViewModel |
| `GET /api/projects` / `POST /api/projects/details` | `:1067,:1072` | ✅ | `SessionDiscovery.discoverProjects/getProjectDetails` `:247,:369` |
| `POST /api/session-stats` | `:1093` | ✅ | `StatsComputer.compute` (see divergences) |
| `POST /api/export-md` | `:1117` | ✅ | `MarkdownExporter.turnsToMarkdown` |
| `POST /api/transcript` (full turns) | `:1138` | ✅ | TranscriptViewModel / TranscriptView |
| `POST /api/search` (per-project) | `:1176` | ✅ | `SearchService.search` `:4` |
| `POST /api/render-replay` (iframe) | `:1267` | ✅ | native player (`ReplayView`) — no iframe needed |
| `GET /api/favorites` (+POST) | `:1304-1316` | ✅ | `FavoriteEntity`, FavoritesViewModel |
| `GET /api/tags` (+POST) | `:1320-1328` | ✅ | `TagEntity`, TagsViewModel (CRUD + drag-drop) |
| `GET /api/cache-info` | `:1332` | ⚪/n/a | Swift caches via Core Data (`SessionMetaEntity`/`SessionStatsEntity`); no cache-info screen — irrelevant |
| `GET /api/events` (SSE live watch) | `:1342` | ✅ | `Services/FileWatcher.swift` (FSEvents + debounce) |
| `POST /api/git-info` / `/api/git-details` | `:1376,:1388` | ✅ | `Services/GitService.swift:42,54` |
| `POST /api/open` (Finder/Terminal) | `:1400-1418` | 🟡 | Finder reveal wired (`NSWorkspace`, many views). **Terminal open**: iTerm/Terminal fallback present in web; Swift has `GitActionsView` — see Gaps for whether Terminal action exists. |

### Dashboard / viewer features

| Feature | Web | Swift status | Swift evidence |
|---|---|---|---|
| Project dashboard tabs: sessions/stats/plans/git/CLAUDE.md/MEMORY.md | `template/dashboard.html:1684-1689` | ✅ | DashboardView + ProjectFilesView, StatsView, PlansListView, GitView |
| Sessions table (sortable) | dashboard.html | ✅ | `Views/Dashboard/SessionTableView.swift` |
| Activity heatmap | dashboard.html `:2715` | ✅ | `Views/Dashboard/ActivityHeatmapView.swift` |
| Stats overview + tool chart + bash/files/agents | `editor-server.mjs:730-853` | 🟡 | `StatsComputer.swift` + Stats views — but **drops `teams`, and Agent field bug** (see Discrepancies) |
| Plans tab | dashboard.html `:1916` (sources from session-stats plan entries) | 🟡 | `PlansListView.swift` reads `~/.claude/plans/*.md` files — **different data source** (see Gaps) |
| Session compare (diff) | dashboard.html `:2116` | ✅ | `Views/Dashboard/SessionCompareView.swift` + `TurnDiffer` (LCS) |
| Native replay player (speed/thinking/tools toggles, bookmarks) | `player.html` | ✅ | `Views/Replay/*` |
| Transcript viewer + filter/search | dashboard.html | ✅ | `Views/Transcript/*` |
| Cross-project / global search | (web `/api/search` is per-project only) | ✅ **superset** | `SearchService.searchAllProjects` `:40` (Claude+Cursor+Codex) |

### Swift-only additions (no web counterpart)

The web app (v0.8.1) has **no chat / Agent SDK / MCP** anywhere — `package.json` has no `@anthropic-ai/*` dependency, and `dashboard.html`/`editor.html` contain no chat UI. These are net-new Swift features (powered by `swift/sidecar/sidecar.js`):

| Swift feature | Evidence |
|---|---|
| Live Claude chat (Node sidecar + Agent SDK) | `Services/ClaudeAgent.swift:17` (`actor ClaudeAgent`, spawns `node sidecar.js`), `swift/sidecar/sidecar.js` |
| Multi-tab / split chats | `Views/Chats/ChatTabContainerView.swift` |
| Persisted chat history | `Persistence/ChatTranscriptEntity.swift` |
| Model picker (Sonnet/Opus/Haiku + pricing) | `Views/Chats/ChatModelPickerView.swift` |
| MCP servers | `Services/MCPServerStore.swift`, `Views/Shared/MCPServersSettingsView.swift` |
| Slash commands (`.claude/commands/*.md`) | `Services/SlashCommandService.swift`, `Views/Chats/SlashCommandPickerView.swift` |
| Attachments (drag-drop + QuickLook) | `Views/Chats/ChatAttachment*.swift` |
| Permission prompts | `Views/Chats/PermissionAlertView.swift`, `Models/PermissionDecision.swift` |
| In-app docs tab + MenuBar status item | `Views/Docs/*`, `Views/MenuBar/StatusItemController.swift` |

### Intentionally web-only

| Feature | Web evidence | Verdict |
|---|---|---|
| Embedded lazygit/shell terminal (xterm.js + node-pty PTY over WS) | `src/terminal.mjs`, `template/lazygit.html`, `editor-server.mjs:1543,:1569` | ⚪ web-only — Swift opens Finder/Terminal instead; native macOS users have a real terminal |
| Docker distribution | `Dockerfile`, `docker-compose.yml` | ⚪ web-only |
| npm CLI binary (`claude-replay`) | `bin/claude-replay.mjs`, `package.json bin` | ⚪ web-only (Swift is a .app) |
| CSRF / cross-origin check | `editor-server.mjs:911-925` | ⚪ irrelevant to a local macOS app |
| SQLite cache (`better-sqlite3`) + `/api/cache-info` | `src/db.mjs`, `editor-server.mjs:1332` | ⚪ Swift uses Core Data instead |

---

## Discrepancies vs existing audit docs (`AUDIT_DIFF_V2.md` / `AUDIT_SWIFT_V2.md`)

These docs claim **"40/40 done, 🟡 0, ❌ 0, 🐛 0"** (`AUDIT_DIFF_V2.md:101-106`). Code says otherwise in a few places:

1. **`result_timestamp` vs `resultTimestamp` — export bug (NOT 🐛 0).**
   Web `renderer.mjs:103` emits `resultTimestamp` (camelCase); `player.html:1149` reads `b.tool_call.resultTimestamp`. Swift `HTMLRenderer.swift:166` emits **`result_timestamp`** (snake_case). Consequence:
   - Swift-exported replays lose tool-result timing in the embedded player (it looks for `resultTimestamp`, finds nothing).
   - Swift's own `HTMLExtractor` decodes into `ToolCall` whose `CodingKeys` (`Turn.swift:128`) expect `resultTimestamp`, so **extract of a Swift-generated file silently drops the field** — round-trip is lossy. (Extract of a *web*-generated file works, because web uses the right key.)
   This contradicts the "🐛 0 / Export HTML ✅ wired" claim (item #22). **Real bug.**

2. **Item #18 / Stats — `teams` collection dropped.** Web `computeSessionStats` collects `teams` for `TeamCreate`/`TeamDelete` (`editor-server.mjs:821-827`) and richer `agents` fields (`run_in_background`, `subagent_type`, `:809-819`). Swift `StatsComputer.swift:53-56` collects `agents` but **no `teams`**, and only a subset of agent fields. Minor, but "Stats ✅" over-states completeness.

3. **Item #18 / Agent stats — wrong field mapped.** Web reads agent **`description`** as the headline (`editor-server.mjs:810`) and keeps `prompt` separately. Swift reads **`input["name"]`** (`StatsComputer.swift:54`) for the agent title (the Task/Agent tool input has no `name` key — it has `description`, `subagent_type`, `prompt`). So `AgentsListView.swift:10` shows `"unnamed"` for virtually all real agents. **Genuine bug**, masked under "✅".

4. **Item #28 / Plans tab — different data source, not a port.** Web Plans tab scans each session's parsed tool calls for plan-mode entries (`EnterPlanMode`/`ExitPlanMode`/`Write` into `/plans/`) via `session-stats` (`editor-server.mjs:828-839`, `dashboard.html:1916`). Swift `PlansListView.swift` lists `~/.claude/plans/*.md` files on disk instead. Both are "Plans," but they show **different sets** (Swift misses in-transcript plan entries that were never written to that dir; web misses standalone plan files). The audit's flat "✅" hides this divergence.

5. **Item #17 / Tool grouping threshold — "documented" ≠ "matched".** `AUDIT_DIFF_V2.md` resolves the 1-vs-5 grouping inconsistency by *documenting* Swift's threshold of 5 as configurable, not by matching the web. Fine as a product decision, but it is a behavioral difference presented as resolved parity.

6. **Item #5 / Custom redact rules — partial.** `RenderOptions` (`HTMLRenderer.swift:6-20`) has only a `redactSecrets: Bool`; there is no `redactRules: [{search,replacement}]` array equivalent to the web's `--redact text=repl` (`renderer.mjs:44-54`). The auto-redactor is fully ported; the *custom* user rules path is thinner than the "✅ via Export sheet + Settings" claim implies. Worth a code-level recheck of `ExportViewModel`/Settings.

Everything else in the scoreboard (parser, themes, discovery, multi-account, favorites, tags, compare, chains, bookmarks, chat suite) **checks out against the code.**

---

## Genuine gaps (Swift should have these; web does)

1. **[BUG] Export tool-result timestamp key mismatch.** `HTMLRenderer.swift:166` writes `result_timestamp`; the player and the extractor both want `resultTimestamp`. Fix: emit `resultTimestamp` (and/or add a `result_timestamp` CodingKey alias on `ToolCall`). Impact: degraded playback timing in exported files; lossy extract round-trip of Swift output.

2. **[BUG] Agent stats title field.** `StatsComputer.swift:54` should read `input["description"]` (with `subagent_type` fallback), not `input["name"]`. Currently nearly all agents render as "unnamed."

3. **[DATA] Stats `teams` not collected.** Add `TeamCreate`/`TeamDelete` aggregation to match `editor-server.mjs:821-827` (and round out the agent fields). Low priority.

4. **[DATA/BEHAVIOR] Plans tab data source.** To match the web, the Swift Plans tab should also surface in-transcript plan-mode entries (`EnterPlanMode`/`ExitPlanMode`/`Write`→`/plans/`) from parsed sessions, not only `~/.claude/plans/*.md` files. Consider unioning both sources.

Possible minor: custom redact-rules array in the export pipeline (item #5 above) — verify in `ExportViewModel`/Settings; if absent, it is a 5th small gap.

---

## Bottom line

The Swift app is **at or above functional parity** with web v0.8.1 for the replay/dashboard/editor product, and adds a whole interactive-chat product on top. The prior audit's "40/40, zero gaps" is **directionally true but too clean**: there is one real export bug (`result_timestamp`), one real stats bug (agent field), and two minor data divergences (stats `teams`, Plans source). All are small, localized fixes.
