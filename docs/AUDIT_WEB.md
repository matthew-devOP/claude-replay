# Audit aplicație web — claude-replay

Audit la nivel de cod sursă al componentei web/Node.js a proiectului `claude-replay` (CLI + server local + template-uri HTML embeddable). Componenta Swift din `swift/` este în afara acestui audit.

---

## Versiune și metadate

- **Versiune curentă:** `0.8.1` (`package.json:3`)
- **Nume pachet npm:** `claude-replay` (`package.json:2`)
- **Tip modul:** ES modules (`"type": "module"`, `package.json:5`)
- **License:** MIT (`package.json:45`)
- **Repo declarat:** `https://github.com/es617/claude-replay` (`package.json:43`)
- **Engines:** `node >= 18` (`package.json:32`)
- **Binary:** `claude-replay` → `bin/claude-replay.mjs` (`package.json:6-8`)
- **Fișiere distribuite în npm:** `bin/`, `src/`, `template/` (`package.json:9-13`)
- **Keywords:** `claude`, `claude-code`, `replay`, `transcript`, `html`
- **Scripts npm:** `build` (minify player template), `test` (node --test), `test:e2e` (Playwright)
- **Ultima intrare în CHANGELOG.md:** `0.4.1` — fix `extract` command pe replay-uri minificate (versiunile 0.5–0.8.1 nu au intrări în CHANGELOG; există decalaj între `package.json` și changelog — vezi secțiunea "Lipsuri/observații").

---

## Arhitectură generală

Proiectul are trei componente coordonate de același CLI:

- **CLI binary** (`bin/claude-replay.mjs:1-409`) — parsează argumente cu `node:util parseArgs`, rutează între:
  - lansare server editor (default, fără argumente sau cu subcomanda `editor`),
  - subcomanda `extract` pentru a recupera datele dintr-un HTML deja generat,
  - generare directă de HTML din unul sau mai multe fișiere de input.
- **Server Node HTTP local** (`src/editor-server.mjs:1434-1651`) — `http.createServer` plus un `WebSocketServer` (`ws`) atașat în `terminal.mjs` pentru sesiuni PTY (lazygit / shell). Servește dashboard-ul, editorul, replay viewer-ul, docs, lazygit page și API-uri JSON sub `/api/*`.
- **Template HTML self-contained** (`template/player.html` 2725 linii + `template/player.min.html` 135 linii minificat) — generat de `src/renderer.mjs` care înlocuiește placeholder-uri stil `/*XXX*/`.

**Flux de bază sesiune → HTML:**

1. Input rezolvat ca path sau session ID (`bin/claude-replay.mjs:160-193`, `src/resolve-session.mjs`).
2. `parseTranscript(filePath)` (`src/parser.mjs:529`) detectează formatul (Claude Code / Cursor / Codex) și produce `Turn[]` normalizat.
3. `filterTurns(...)` aplică range-uri, exclude-uri, ferestre temporale (`src/parser.mjs:667`).
4. `applyPacedTiming(turns)` opțional (pacing sintetic — `src/parser.mjs:645`).
5. `render(turns, opts)` (`src/renderer.mjs:120`) construiește HTML din template + theme CSS + JSON comprimat (deflate+base64) sau JSON brut escape-uit pentru `<script>`.
6. Output către stdout sau fișier; `--open` îl deschide în browser.

În modul editor, `editor-server.mjs` ține în memorie un `Map<sessionId, {originalTurns, workingTurns, sourcePath, format}>` și expune endpoint-uri de tip CRUD pe turns plus `/api/preview` și `/api/export` care reapelează același `renderer.mjs`.

---

## Entry points

Subcomenzile și modurile expuse de `bin/claude-replay.mjs`:

- **Fără argumente** → pornește editorul web (`bin/claude-replay.mjs:71-79`). Implicit `127.0.0.1:7331`.
- **`editor`** → identic cu fără argumente (pornește serverul explicit).
- **`extract <replay.html> [-o output.json]`** → recuperează `turns` + `bookmarks` din replay generat (`bin/claude-replay.mjs:132-158`, `src/extract.mjs:76`).
- **`<input1> [input2 …] [options]`** → mod CLI generare. Inputurile pot fi căi de fișier sau session ID-uri rezolvate prin `resolveSessionId` (`bin/claude-replay.mjs:160-193`). Maxim 20 inputuri concatenate (`bin/claude-replay.mjs:161`).
- **`--list-themes`** și **`--version` / `-v`** sunt comenzi de tip "exit imediat" (`bin/claude-replay.mjs:57-68`).
- **`--help` / `-h`** afișează help-ul complet (`bin/claude-replay.mjs:81-129`).

---

## Funcționalități — CLI

Toate flag-urile declarate în obiectul `options` din `bin/claude-replay.mjs:16-45`:

**Server editor:**
- `--port N` — port pentru server (default `7331`, `bin/claude-replay.mjs:75`).
- `--host` — host pentru bind (default `127.0.0.1`, `bin/claude-replay.mjs:76`).

**Output:**
- `-o, --output FILE` — fișier HTML de ieșire; fără el iese pe stdout (`bin/claude-replay.mjs:396-409`).
- `--open` — deschide HTML-ul după generare (necesită `-o`); folosește `open`/`start`/`xdg-open` în funcție de platformă (`bin/claude-replay.mjs:399-403`).
- `--no-minify` — folosește templatul `player.html` în loc de `player.min.html` (`bin/claude-replay.mjs:40`).
- `--no-compress` — embed JSON brut în loc de deflate+base64 (`bin/claude-replay.mjs:41`, `src/renderer.mjs:167-173`).

**Selectare turns:**
- `--turns N-M` — range inclusiv (`bin/claude-replay.mjs:219-232`).
- `--exclude-turns N,N,...` — listă de indici excluși (`bin/claude-replay.mjs:236-245`).
- `--from TIMESTAMP` / `--to TIMESTAMP` — filtrare ISO 8601 (`src/parser.mjs:680-694`).

**Timing/playback:**
- `--speed N` — viteza inițială (default `1`, clamped între `0.1` și `10` în renderer `src/renderer.mjs:136`).
- `--timing auto|real|paced` — auto folosește timestamp-urile reale dacă există, altfel paced (`bin/claude-replay.mjs:291-299`).

**Vizibilitate blocuri:**
- `--no-thinking` — ascunde implicit blocurile thinking în output.
- `--no-tool-calls` — ascunde implicit blocurile tool_use.

**Theming:**
- `--theme NAME` — temă built-in (default `tokyo-night`).
- `--theme-file FILE` — JSON custom care moștenește variabilele din `tokyo-night` (`src/themes.mjs:220-227`).
- `--list-themes` — listează temele și ieșire imediată.

**Redaction:**
- `--no-auto-redact` — dezactivează pattern-urile de secrete built-in.
- `--redact "text"` sau `--redact "text=replacement"` — repetabil, înlocuire literală (`bin/claude-replay.mjs:370-377`).

**Etichete și meta:**
- `--title TEXT` — title HTML; default derivat din numele directorului părinte (`bin/claude-replay.mjs:303-316`).
- `--description TEXT` — meta description pentru OG/Twitter (`src/renderer.mjs:129`).
- `--og-image URL` — image pentru OG/Twitter card (default hosted: `https://es617.github.io/claude-replay/og.png`, `src/renderer.mjs:130`).
- `--user-label NAME` — label pentru mesajele user (default `User`).
- `--assistant-label NAME` — auto-detected: `Codex` pentru codex, `Assistant` pentru cursor, `Claude` pentru claude-code (`bin/claude-replay.mjs:387`).

**Bookmarks:**
- `--mark "N:Label"` — repetabil (`bin/claude-replay.mjs:321-336`).
- `--bookmarks FILE` — JSON array `[{turn, label}]` (`bin/claude-replay.mjs:338-361`).

**Info:**
- `-v, --version`, `-h, --help`.

---

## Funcționalități — Web Editor

Editorul (URL `/editor`) este servit din `template/editor.html` (1772 linii) și folosește API-urile expuse de `src/editor-server.mjs:911-1421`.

**Layout (trei panouri, `editor.html:354+`):**
- **Stânga — Sidebar Sessions/Options:**
  - Tree sesiuni (Claude Code / Cursor / Codex), grupate pe grup → proiect → fișier (`editor-server.mjs:329-430`, endpoint `GET /api/sessions`).
  - Filter input pentru sesiuni (`editor.html:732`).
  - "Open Folder" — file browser arbitrar, restricționat la `$HOME` (`editor.html:735-740`, endpoint `POST /api/browse`, `editor-server.mjs:290-327`).
  - Account switcher pentru `~/.claude*` (`editor-server.mjs:79-108`, dropdown injectat la runtime în `injectShared`).
  - Theme dropdown live (variabile aplicate prin `style.setProperty`) — folosește datele din `/*THEMES_JSON*/` injectate de server.
  - Panel "Options": preset, theme, speed, thinking/tools toggle, auto-redact + custom redact rules, user-label, assistant-label, description, og-image, timing, minify, compress (`editor.html:747-820`).
- **Centru — Turn editor:**
  - Toolbar: `Include All`/`Exclude All`, filtru after type (user/assistant/tool/thinking), jump to turn (`editor.html:826-841`).
  - Listă turns cu user_text editabil (textarea live), blocuri assistant read-only colapsabile, checkbox include/exclude per turn, buton bookmark + label input.
  - Edit user_text → `POST /api/edit` (`editor-server.mjs:1013-1023`).
- **Dreapta — Live preview:**
  - `<iframe>` care primește HTML-ul randat (`editor.html:854`).
  - Preview se actualizează prin `POST /api/preview` (`editor-server.mjs:1026-1034`) cu debouncing.

**Operațiuni cheie:**
- **Load:** `POST /api/load { path }` — parsează JSONL, reutilizează sesiunea dacă există în cache (`editor-server.mjs:973-1010`).
- **Reset:** `POST /api/reset` — restaurează `workingTurns` din `originalTurns` (`editor-server.mjs:1057-1064`).
- **Export:** `POST /api/export` — descarcă HTML self-contained (`Content-Disposition: attachment`), respectă minify/compress (`editor-server.mjs:1037-1054`).
- **Search/filter** turns prin input local.
- **Resize handle** între panou centru și preview (`editor.html:846`).
- **Help modal**, dark/light toggle, sidebar toggle.

Privacy notice: editorul rulează exclusiv pe `127.0.0.1`; o verificare anti-CSRF respinge requesturile cu Origin străin (`editor-server.mjs:914-925`). Fișierele JSONL originale nu sunt modificate niciodată.

---

## Funcționalități — Web Dashboard

Dashboard-ul este landing page-ul la `/` (`template/dashboard.html`, 2938 linii). Servit prin `editor-server.mjs:1511-1518`.

**Structură:**
- **Topbar:** "Projects" link, global search input (caută în toate sesiunile dintr-un proiect via `POST /api/search`, `editor-server.mjs:1176-1264`), dark/light toggle, account dropdown, theme dropdown, help button (`?`), mobile menu (`dashboard.html:1199-1227`).
- **Sidebar:** listă proiecte (sursa Claude — `editor-server.mjs:569-611`), filtru text + sort (sessionCount asc/desc, etc.), favorites section.
- **Detail view pentru un proiect:**
  - Header cu statistici agregate (total sesiuni, total turns, dimensiune, date range).
  - Acțiuni rapide: "Open in Finder" / "Open in Terminal" (`POST /api/open`, `editor-server.mjs:1399-1419`) / "Open LazyGit" (rută `/lazygit`).
  - **Tabs:**
    - `Sessions` — heatmap activitate (`renderHeatmap`, `dashboard.html:2683`) + tabel sortabil cu coloane: Session ID (8 char), Preview, Date, Duration, Turns, Size, Actions (Replay/Transcript/Edit/MD/Compare). Star button pentru favorite (`dashboard.html:2057-2123`).
    - `Stats` — încarcă lazy via `POST /api/session-stats` (`editor-server.mjs:1093-1114`), cu cache SQLite (`computeSessionStats`, `editor-server.mjs:730-853`): tool breakdown, bash commands, files read/edited, agents, etc.
    - `Plans` — listă apelurilor `EnterPlanMode`/`ExitPlanMode` + scrierile în `*/plans/*`.
    - `Git` — info detaliat dacă proiectul e repo git (`POST /api/git-details`, `editor-server.mjs:497-519`): branch curent, branches locale/remote, recent commits, ASCII graph (`git log --graph`).
    - `CLAUDE.md` / `MEMORY.md` (când există) — display markdown brut (`editor-server.mjs:625-631`).
- **Transcript overlay:** open full transcript fără export (`POST /api/transcript`, `editor-server.mjs:1138-1173`); include search box cu Enter/Shift+Enter, filtre per rol (user/assistant/tools/thinking).
- **Compare Sessions:** diff/compare în overlay (`dashboard.html:1288-1289`).
- **Favorites:** GET/POST `/api/favorites` (`editor-server.mjs:1304-1316`).
- **Tags:** GET/POST `/api/tags` (`editor-server.mjs:1320-1328`).
- **SSE live updates:** `GET /api/events` (`editor-server.mjs:1342-1373`) emite `sessions-changed` la fiecare 10s dacă numărul total de sesiuni se schimbă, plus heartbeat la 30s; client-side `EventSource` în `dashboard.html:2911-2926`.

**Keyboard shortcuts dashboard (`dashboard.html:2883-2899`):**
- `?` — toggle help modal
- `1` — Projects
- `2` — Editor (`/editor`)
- `3` — Docs (`/docs`)
- `Esc` — închide modal/transcript overlay

---

## Funcționalități — Player HTML generat

Player-ul (template `template/player.html`, 2725 linii unminified) este componenta self-contained livrată la export.

**Layout (`player.html:1030-1095`):**
- Controls bar: Prev / Play / Next, title, progress text, chapter dropdown, speed popover, filter popover (Thinking / Tools), export popover (Markdown / PDF), more popover (mobile).
- Progress bar cu turn dots + bookmark dots + tooltip pe hover.
- Splash screen cu play button mare.
- Transcript container care randează turn-urile (markdown rendering inline `renderMarkdown`, `inlineMarkdown`, syntax highlighting fence-uri).

**Funcționalități:**
- **Block-by-block animation** controlat de `ANIMATE_MIN_DELAY` etc.
- **Tool grouping:** secvențe consecutive de tool_use grupate într-un singur `tool-group` colapsabil (`player.html:1547-1559`).
- **Diff view** pentru Edit (linii roșii `−`, linii verzi `+` — `player.html:1364-1376`).
- **Code block view** pentru Write (`player.html:1381-1385`).
- **Bash header preview** cu prefix `$`, file_path pentru Edit/Write/Read, pattern pentru Grep/Glob.
- **Failed tool indicator:** dot roșu + result text roșu (`is_error`).
- **Collapsible** pentru text/diff lung (`wrapCollapsible`, threshold default 15 linii, `player.html:1403-1411`).
- **Markdown rendering:** inline + fence-uri cu language class (`player.html:1231+`).
- **Speed control:** popover cu opțiuni (0.5x – 5x), persistat.
- **Bookmarks/Chapters:** dropdown navigare; click oprește playback (`player.html:2527+`).
- **Splash:** afișat la load fără hash, sau cu `#turn=0`; ascuns la play sau cu `#turn=N`.
- **Deep links:** `#turn=N` (test acoperit în Playwright).
- **Iframe detection:** compact mode, click pe titlu deschide într-un tab nou cu deep link (`player.html:2494-2504`).
- **Print → PDF:** browser print dialog.
- **Export Markdown:** buton din player.

**Keyboard shortcuts (`player.html:2482-2491`):**
- `Space` / `K` — play/pause
- `→` / `l` — pas următor (block sau turn)
- `←` / `h` — pas anterior
- `Shift+→` / `Shift+L` — sare la turnul următor
- `Shift+←` / `Shift+H` — sare la turnul anterior
- `t` — sare la următorul block thinking/tool
- `Shift+T` — sare la precedentul

**Meta tags (`player.html:9-16`):** OG (`og:title`, `og:description`, `og:type`, `og:image`) + Twitter card (`summary_large_image`).

---

## Parser și formate suportate

`src/parser.mjs` (697 linii). Detecție automată după peek pe prima linie validă (`detectFormatFromText`, `parser.mjs:71-83`):

- `obj.type === "session_meta"` → **Codex CLI**
- `obj.type === "user"|"assistant"` → **Claude Code**
- `obj.role === "user"|"assistant"` (fără top-level `type`) → **Cursor**

**Claude Code JSONL (`parseTranscript` cu helper `parseJsonl`, `parser.mjs:529-638`):**
- Parcurge linie cu linie, normalizează în Turn-uri user→assistant.
- Absoarbe consecutive user messages non-tool_result în același turn (`parser.mjs:554-563`).
- Atașează tool_results la tool_use prin `tool_use_id` (`attachToolResults`, `parser.mjs:182-235`).
- Curăță tag-uri sistem cu `cleanSystemTags` (`parser.mjs:16-43`): `<system-reminder>`, `<task-notification>`, `<user_query>`, `<ide_opened_file>`, `<local-command-caveat>`, `<command-name>`, `<command-message>`, `<command-args>`, `<local-command-stdout>`.
- Extrage system events `[bg-task: ...]` separat (`parser.mjs:566-571`).
- Filtrează turn-uri goale și mesajele "No response requested."

**Cursor (`parser.mjs:106-112`, `626-635`):**
- Schemă: top-level fără `type`, doar `role` + `message.content`.
- Conversia la formă Claude Code: `{ type: role, message: { role, content }, timestamp }`.
- Toate blocurile assistant cu excepția ultimului per turn sunt re-marcate ca `thinking`.

**Codex CLI (`parseCodexTranscript`, `parser.mjs:314-522`):**
- Format event-based cu boundaries `event_msg/task_started` și `event_msg/task_complete`.
- `extractCodexUserText` strip-uiește IDE context, environment, permissions, skills — caută markerul `## My request for Codex:`.
- `response_item/message` cu phase `commentary` → thinking, phase implicit/`final_answer` → text.
- `function_call` cu name `exec_command` → mapat la `Bash` (cmd+workdir → `cd workdir && cmd`).
- `function_call_output` → result cu strip de metadata (`Chunk ID`, `Wall time`, `Process exited`).
- `custom_tool_call` cu name `apply_patch` → parsat prin `parseCodexPatch` (`parser.mjs:246-288`):
  - `*** Add File:` → `Write` (cu `content`).
  - `*** Update File:` → `Edit` (cu `old_string` / `new_string`).
- `reasoning` (encrypted CoT) → skip.

**Concatenare multi-input (`bin/claude-replay.mjs:247-270`):**
- Sortare cronologică dacă toate sesiunile au timestamp-uri.
- Re-indexare secvențială globală a turn-urilor.

---

## Renderer și template engine

`src/renderer.mjs` (176 linii). Template engine ad-hoc bazat pe placeholder-uri stil comentariu CSS/JS `/*NAME*/`.

- Citește `template/player.min.html` (sau `player.html` cu `--no-minify`).
- Înlocuiește în ordine placeholder-urile (`renderer.mjs:152-162`): `THEME_CSS`, `THEME_BG`, `INITIAL_SPEED` (cu fallback `/1` ca valoare implicită JS pentru a păstra sintaxa validă), `CHECKED_THINKING`, `CHECKED_TOOLS`, `PAGE_TITLE`, `PAGE_DESCRIPTION`, `OG_IMAGE`, `USER_LABEL`, `ASSISTANT_LABEL`.
- `BOOKMARKS_DATA` și `TURNS_DATA` sunt injectate ultimele (`renderer.mjs:167-173`), pentru a evita coliziuni cu placeholder-uri care apar literal în transcripts.
- Compresie: `deflateSync` + `base64` (default) sau JSON brut escape-uit cu `escapeJsonForScript` (`renderer.mjs:24-32`) care protejează `</`, `<!--`, ghilimele, newlines.
- Theme injectat ca `themeToCss(theme)` (`src/themes.mjs:234-242`) plus `extraCss` opțional.

**Build-time minification (`scripts/build-template.mjs`):**
- Citește `template/player.html`, scoate `<style>` și `<script>` și le minifică cu **esbuild** (`scripts/build-template.mjs:69-72`).
- Înlocuiește placeholder-urile `/*XYZ*/` cu token-uri sentinel (`__PLACEHOLDER_*__`) înainte de minify, le restaurează după (`scripts/build-template.mjs:21-43`, `86-97`).
- Validează că nu rămân placeholder-uri necunoscute și că toate token-urile sunt restaurate.
- Outputează `template/player.min.html` (~135 linii vs. 2725).

---

## Redaction / Secrets

`src/secrets.mjs` (83 linii). Două componente:

- `redactSecrets(text)` (`secrets.mjs:56`) — aplică în ordine pattern-urile globale din `SECRET_PATTERNS` (`secrets.mjs:8-49`):
  - `private_key` (`-----BEGIN ... PRIVATE KEY-----`)
  - `aws_key` (`AKIA[0-9A-Z]{16}`)
  - `sk_ant_key` (`sk-ant-...`)
  - `sk_key` (`sk-...{20+}`)
  - `key_prefix` (`key-...{20+}`)
  - `bearer` (`Bearer <token>`)
  - `jwt` (header.payload.signature)
  - `connection_string` (`mongodb://`, `postgres://`, `mysql://`, `redis://`, `amqp://`, `mssql://`)
  - `key_value` (heuristic `api_key=`, `secret_key:`, `bearer:`, etc.)
  - `env_var` (`PASSWORD=`, `TOKEN=`, `SECRET=`, `CREDENTIAL=`, `PRIVATE_KEY=`)
  - `hex_token` (40+ hex chars cu word boundary)
- `redactObject(obj)` — walk recursiv pe stringuri.

**Activare/control:**
- Default activat în `render(...)` (`renderer.mjs:131`).
- Dezactivat cu `--no-auto-redact` (CLI) sau `options.redactSecrets === false` (editor API).
- Reguli custom: `--redact "search=replace"` repetabil (CLI) sau `options.redactRules` (editor); aplicate atât pe text, cât și pe tot obiectul tool_call.input prin `transformStrings` (`renderer.mjs:62-73`).

---

## Teme

`src/themes.mjs` (268 linii). Teme built-in (`BUILTIN_THEMES`, `themes.mjs:15-199`):

- `claude-dark`
- `claude-light`
- `tokyo-night` (default CLI, `bin/claude-replay.mjs:27`)
- `monokai`
- `solarized-dark`
- `github-light`
- `dracula`
- `bubbles` — singura cu `extraCss` (`themes.mjs:159-198`), layout chat-bubble cu emoji 👤 și 🤖, mesaje colorate și colțuri rotunjite.

**Variabile expuse (`THEME_VARS`, `themes.mjs:7-13`):**
`bg`, `bg-surface`, `bg-hover`, `text`, `text-dim`, `text-bright`, `accent`, `accent-dim`, `green`, `blue`, `orange`, `red`, `cyan`, `border`, `tool-bg`, `thinking-bg`.

**API:**
- `getTheme(name)` — aruncă cu lista temelor disponibile dacă nu există.
- `listThemes()` — returnează numele sortate.
- `loadThemeFile(path)` — merge cu defaults din `tokyo-night`.
- `getAllThemes()` — strip-uiește `extraCss`, returnează maps clean pentru client-side switching (folosit în `editor-server.mjs:1439` injectat ca `/*THEMES_JSON*/`).
- Default-ul renderer-ului este `claude-dark` (`renderer.mjs:125`), default-ul CLI este `tokyo-night`.

---

## Session discovery & resolver

`src/resolve-session.mjs` (126 linii). Funcția `resolveSessionId(sessionId, { home })` scanează în ordine:

- **Claude Code:** toate `~/.claude*` (dir match `^.claude([-_].+)?$`) → `<dir>/projects/<project>/<id>.jsonl` (`resolve-session.mjs:14-66`). Etichetă "main" pentru `.claude`, restul după sufix (`.claude-work` → `work`).
- **Cursor:** `~/.cursor/projects/<project>/agent-transcripts/<sessionId>/transcript.jsonl` (sau `<id>.jsonl` fallback) (`resolve-session.mjs:68-87`).
- **Codex CLI:** `~/.codex/sessions/<YYYY>/<MM>/<DD>/rollout-<timestamp>-<uuid>.jsonl` cu match pe filename exact sau pe UUID-ul de după prefixul timestamp (`resolve-session.mjs:89-123`).

Returnează `{ path, project, group }[]`. CLI tratează:
- 0 matches → error,
- 1 match → folosit,
- multiple → afișează lista și exit non-zero (`bin/claude-replay.mjs:179-188`).

Same logic e replicat în editor pentru discovery via `discoverSessions` (`editor-server.mjs:329-430`) și `discoverProjects` (`editor-server.mjs:569-611`).

---

## Persistență

`src/db.mjs` (205 linii). SQLite via `better-sqlite3`. Database la `${CLAUDE_REPLAY_DATA || ~/.claude-replay}/cache.db` (`db.mjs:14-16`). PRAGMA `journal_mode=WAL`, `synchronous=NORMAL`.

**Schema (`db.mjs:30-72`):**
- `session_meta(path PK, project_dir, session_id, file_mtime, file_size, turn_count, duration, preview, user_previews JSON, first_timestamp, last_timestamp, cached_at)` cu index pe `project_dir`. Invalidare prin compararea `file_mtime` (`db.mjs:77-93`).
- `session_stats(path PK, file_mtime, stats_json, cached_at)` — cache pentru `computeSessionStats`.
- `favorites(path PK, session_id, preview, project_dir, pinned_at)`.
- `tags(path, tag, created_at, PRIMARY KEY (path,tag))` cu index pe `path`.

**API exportat:**
- `getCachedMeta` / `setCachedMeta` / `getCachedStats` / `setCachedStats`
- `getFavorites` / `addFavorite` / `removeFavorite` / `isFavorite`
- `getTagsForSession` / `getAllTaggedSessions` / `addTag` / `removeTag` / `setTags`
- `getCacheInfo` (counts + size + path).

**Graceful fallback (`editor-server.mjs:14-28`):** dacă `better-sqlite3` nu se instalează (e.g. lipsă toolchain native), modulul DB e nul și toate funcțiile devin no-ops; aplicația rulează în continuare fără persistență.

---

## Terminal integration

`src/terminal.mjs` (129 linii). Server WebSocket atașat pe `/ws/terminal` (`terminal.mjs:23-128`).

- Folosește `node-pty` (`pty.spawn`) cu fallback graceful dacă nu e instalat (`terminal.mjs:11-17`).
- Query params: `path` (cwd), `cmd` (default `lazygit`), `cols`, `rows`.
- Spawn-ează `lazygit` direct sau `$SHELL -c <cmd>`; dacă comanda eșuează, fallback la shell și mesaj galben `⚠ <cmd> not found, opened shell instead.`
- Setează `TERM=xterm-256color`, `COLORTERM=truecolor` și suprascrie `XDG_CONFIG_HOME` / `XDG_DATA_HOME` / `XDG_STATE_HOME` la `${CLAUDE_REPLAY_DATA}/...` (pentru izolarea config-ului lazygit în Docker).
- Mesaje JSON `{type:"resize", cols, rows}` declanșează `pty.resize`.

**UI (`template/lazygit.html`, 233 linii):** încarcă `xterm.js` + addon-uri (`fit`, `web-links`) prin `/assets/xterm/*` (servite din `node_modules` de către `editor-server.mjs:1569-1590`).

---

## Integrări și dependențe

**Dependencies (`package.json:19-26`):**
- `better-sqlite3 ^11.7.0` — cache persistent SQLite (session metadata, stats, favorites, tags). Optional la runtime.
- `node-pty ^1.0.0` — spawn PTY pentru lazygit/shell. Optional la runtime.
- `ws ^8.18.0` — server WebSocket pentru `/ws/terminal`.
- `@xterm/xterm ^5.5.0` — emulator terminal în browser.
- `@xterm/addon-fit ^0.10.0` — auto-resize terminal după container.
- `@xterm/addon-web-links ^0.11.0` — linkuri clicabile în output terminal.

**Dev dependencies (`package.json:27-30`):**
- `esbuild ^0.25.0` — minify CSS+JS în `scripts/build-template.mjs`.
- `@playwright/test ^1.58.2` — teste e2e pentru editor și player.

**Lipsuri notabile:** zero dependențe runtime pentru parser/renderer/CLI — toate funcționalitățile core folosesc strict module Node built-in (`node:fs`, `node:zlib`, `node:http`, `node:util`, etc.). Player-ul exportat nu are dependențe externe — totul inline.

**Variabile de mediu:**
- `CLAUDE_REPLAY_DATA` — directorul pentru SQLite cache + lazygit config (default `~/.claude-replay`).
- `CLAUDE_CONFIG_DIR` (referit în comentariul `editor-server.mjs:46`) — manipulează ce `~/.claude*` e implicit.
- `HOME`, `SHELL`, `TERM`, `COLORTERM`.

---

## Distribuție

**npm:**
- `bin: { "claude-replay": "bin/claude-replay.mjs" }` (`package.json:6-8`).
- `files: ["bin/", "src/", "template/"]` (`package.json:9-13`).
- Cross-platform: comanda `--open` folosește `open` (macOS), `start` (Windows), `xdg-open` (Linux) (`bin/claude-replay.mjs:400-402`).

**Docker (`Dockerfile`):**
- Base `node:22-alpine`.
- Instalează `git`, `python3`, `make`, `g++` (pentru native modules), `curl`.
- Descarcă cea mai recentă versiune lazygit din GitHub releases.
- `npm install` + `npm run build` (minify template).
- Expune `7331`; CMD `node bin/claude-replay.mjs --port 7331 --host 0.0.0.0`.

**docker-compose.yml:**
- Port `7331:7331`.
- Volume read-only pentru date: `~/.claude`, `~/.claude-work`, `~/.claude-outlook`, `~/.claude-yahoo`, `~/.cursor`, `~/.codex`.
- Mount rw pe `$HOME` (necesar lazygit pentru commit/push).
- Volume dev pentru `src/`, `template/`, `bin/`, `package.json` (live reload fără rebuild).
- `CLAUDE_REPLAY_DATA=/app/data` izolează datele aplicației în container.

---

## Testare

**Unit / integration (`node --test`, suite în `test/test-*.mjs`):**
- `test-parser.mjs` (46 `it`) — `parseTranscript` Claude Code + Cursor + Codex, `filterTurns`, `applyPacedTiming`, `cleanSystemTags`, `parseCodexPatch`, Codex edge cases.
- `test-secrets.mjs` (17) — `redactSecrets` (toate pattern-urile) și `redactObject`.
- `test-renderer.mjs` (16) — generare HTML, placeholder safety, compress vs raw.
- `test-themes.mjs` (6) — `getTheme`, `listThemes`, `themeToCss`, `loadThemeFile`.
- `test-resolve-session.mjs` (15) — rezolvare ID în Claude/Cursor/Codex paths.
- `test-cli.mjs` (10) — flag-uri CLI end-to-end.
- `test-concat.mjs` (6) — concatenare multi-sesiune.
- `test-extract.mjs` (9) — `extract` subcommand pe replay-uri compressed/uncompressed/minified.
- `test-editor-server.mjs` (15) — API editor (load, edit, preview, export, browse, reset).

**End-to-end (`@playwright/test`, `test/e2e/`):**
- `player.spec.mjs` (35 teste) — splash, deep links, step, expand/collapse, keyboard shortcuts, progress bar, chapters, diff view, Write tool, error indicators, compressed vs uncompressed mode.
- `editor.spec.mjs` (23 teste) — load session, edit text, include/exclude, bulk, bookmarks, options, dark/light, sidebar, export download, reset, deep link click.

**Fixtures (`test/`):** `fixture.jsonl`, `fixture-cursor.jsonl`, `fixture-codex.jsonl`, `fixture-codex-patch.jsonl`, `fixture-codex-edges.jsonl`, `fixture-paced.jsonl`, `fixture-system-tags.jsonl`. Plus `AGENT-SMOKE-TEST.md` și `HUMAN-SMOKE-TEST.md`.

**Total teste:** ≈140 unit + 58 e2e.

---

## Lipsuri/observații

- **Decalaj versiune ↔ CHANGELOG:** `package.json` are `0.8.1`, dar `CHANGELOG.md` se oprește la `0.4.1`. Versiunile 0.5–0.8.1 nu sunt documentate în CHANGELOG (cele adăugate ulterior: dashboard, account switcher, projects browser, SQLite cache, lazygit, terminal WebSocket, SSE live updates).
- **Repo URL inconsistent:** `package.json:43` indică `https://github.com/es617/claude-replay`, dar link-ul din editor help modal (`template/editor.html:903`) e `https://github.com/anthropics/claude-replay` — referință incorectă către `anthropics/`.
- **`isFavorite` și `getTagsForSession` exportate din `db.mjs`** dar nu sunt apelate explicit din `editor-server.mjs` (sunt importate dar nefolosite în handlerele HTTP) — cod mort sau rezervat pentru uz viitor (`editor-server.mjs:24-25`).
- **CHANGELOG menționează `extraCss` și `--theme-file`** ca features în 0.1.0 — corect, dar `--no-thinking`/`--no-tool-calls` nu sunt documentate explicit nicăieri în README/CHANGELOG (apar doar în help-ul CLI).
- **Tests `test-cli.mjs` și `test-extract.mjs`** au numele tag-uite cu `0` în grep-ul `test\(` — folosesc `describe`+`it` (node:test), nu `test()` direct (de la Playwright). Sunt valid, doar diferiți runneri.
- **OG image default hardcodat la GitHub Pages:** `https://es617.github.io/claude-replay/og.png` (`renderer.mjs:130`) — dependent de un repo extern care nu e deținut de proiectul în git status (`anonymous-dd` ca user vs `es617` ca repo).
- **Endpoint-ul `/api/render-replay` apare de două ori** în logica de routing (`editor-server.mjs:1604-1606` și apoi la `1608` prin fallback `/api/*`) — redundant dar inofensiv.
- **Maxim 20 inputuri concatenate** (`bin/claude-replay.mjs:161`) — limită hard-coded, nu configurabilă.
- **Tool grouping threshold** (CHANGELOG 0.2.0 spune "raise to 5") nu apare ca constantă cu nume vizibil — toate `tool_use` consecutive sunt grupate, fără prag (`player.html:1547-1559`).
- **Nu există output JSON sau text-only** ca format alternativ în CLI — doar HTML self-contained (există `extract` invers, dar nu generare directă JSON).
- **`LICENSE` lipsește** local (vezi `git status: D LICENSE`) deși `package.json` declară MIT.
- **Docker dev mode:** docker-compose montează src/template/bin read-only — schimbările locale necesită restart container pentru a reflecta (nu există watch).
- **`spinnerVerbs.mjs`** (190 linii) e auto-extras din `theclaude-mtw/src/constants/spinnerVerbs.ts` (vezi comentariul liniei 1) — dependent de un repo extern pentru update-uri.
