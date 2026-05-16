# Plan de improvements — Aplicație web claude-replay (v0.8.1)

Plan curat de fix-uri și polish pentru componenta web (Node CLI + server local + template HTML) bazat pe [AUDIT_WEB.md](AUDIT_WEB.md) și [AUDIT_DIFF.md](AUDIT_DIFF.md), plus oportunități descoperite în-place în cod. Scop explicit: îmbunătățiri mici/medii fără să destabilizeze ce funcționează deja (npm + Docker + docker-compose, ~140 unit + 58 e2e teste).

---

## Sumar

- Aplicația e **stabilă și deployable**: 0.8.1 publicat, parser/renderer/redaction acoperite de teste, fallback grațios la `better-sqlite3`/`node-pty`. Niciun TODO/FIXME în cod (`grep` 0 rezultate în `src/`/`bin/`/`template/`).
- Restanțele rămase sunt în trei categorii: (a) **drift între artefacte** (CHANGELOG vs `package.json`, URL repo inconsistent în UI, `LICENSE` șters local), (b) **slăbiciuni de securitate minore** (CSRF doar prin Origin, fără SameSite cookies; `/api/browse` se bazează pe `startsWith(home)` susceptibil la symlink, `/api/open` permite orice cale sub `$HOME`), (c) **polish UX** (lipsă paginare/rate-limit, sync I/O pe hot path, accessibility zero în `player.html`, lipsă cross-platform pentru `/api/open`).
- Total efort estimat (toate prioritățile): **~8-12 zile-om** (P0 ~1.5 zile, P1 ~2.5 zile, P2 ~2 zile, restul rafinare pe arie ~4-6 zile).
- Tipul de improvements: fixuri punctuale, hardening, deduplicări mici. **Niciun rewrite, niciun framework nou.** Feature-uri mari (chat live, mobile) — la `Out of scope`.

---

## P0 — Critical fixes

### P0.1 — Restaurează `LICENSE` în repo
- **Problemă:** `package.json:45` declară licența `MIT`, dar fișierul `LICENSE` apare ca șters local (`git status: D LICENSE`). Distribuția pe npm va include `package.json` cu MIT dar fără text de licență.
- **File:** rădăcina repo (`LICENSE`)
- **Soluție:** `git restore LICENSE` (există încă în HEAD). Adaugă un check în CI: `test -f LICENSE` înainte de publish.
- **Efort:** 0.25 h. [AUDIT_WEB.md § Lipsuri](AUDIT_WEB.md#lipsuriobservații)

### P0.2 — `assertUnderHome` e vulnerabil la symlink + edge case `$HOME` cu slash final
- **Problemă:** `src/editor-server.mjs:291-300` validează doar `resolved.startsWith(home + "/")`. Un symlink sub `$HOME` care țintește în afara `$HOME` (ex. `~/extlink → /etc`) trece de check, pentru că `resolve()` nu urmează symlinks. În plus, dacă `$HOME` ar fi `/` (improbabil dar valid), check-ul `startsWith(home + "/")` devine `startsWith("//")` → fail.
- **File:** `src/editor-server.mjs:291-300`
- **Soluție:** Folosește `fs.realpathSync(resolved)` apoi compară cu `realpathSync(home) + sep` (sau `=== realHome`). Adaugă test e2e: symlink care țintește `/etc` să returneze EACCES. Pentru OS Windows, folosește `path.sep` în loc de `/` hard-coded.
- **Efort:** 1.5 h.

### P0.3 — `/api/open` permite execuție arbitrară de aplicații sub `$HOME`
- **Problemă:** `src/editor-server.mjs:1399-1419` acceptă `action: "terminal"` care invocă `open -a iTerm <path>` fără validare strictă pe `action`. Câmpul `body.action` e doar enumerat textual; un atacator cu access la CSRF (orice cale care ocolește check-ul Origin) ar putea declanșa launch. Plus: nu există branch Windows/Linux — pe non-macOS comanda eșuează silent.
- **File:** `src/editor-server.mjs:1399-1419`
- **Soluție:** Whitelist explicit pentru `action` (constant array `["finder", "terminal"]`); add `process.platform === "darwin"` guard cu mesaj clar pe Linux/Windows. Pentru terminal, folosește același `xdg-terminal-emulator`/`wt`/`open -a Terminal` cross-platform ca CLI.
- **Efort:** 2 h.

### P0.4 — Re-citire template la fiecare request pe `/replay`, `/lazygit`, `/docs`
- **Problemă:** `src/editor-server.mjs:1531-1601` face `readFileSync` sincron pe template-ul HTML la **fiecare** request GET pentru aceste rute. Pentru dashboard și editor templates sunt pre-cached (`editorHtml`, `dashboardHtml` la `1494-1498`), dar restul nu — DoS minor + latență.
- **File:** `src/editor-server.mjs:1531-1601`
- **Soluție:** Pre-cache toate template-urile statice la startup (similar cu `editorHtml`/`dashboardHtml`). În `injectShared`, lazy-init și memo-uire cu Map. Reload la modificarea pe disc doar în mod dev (flag `--dev`).
- **Efort:** 1.5 h.

### P0.5 — Help modal trimite utilizatorul la un repo inexistent (`anthropics/claude-replay`)
- **Problemă:** `template/editor.html:903` are link hard-coded la `https://github.com/anthropics/claude-replay` (repo care nu există / nu e al proiectului). `package.json:43` declară `https://github.com/es617/claude-replay`. Utilizatorii care dau click pe "Report an issue" ajung la 404.
- **File:** `template/editor.html:903`
- **Soluție:** Înlocuiește cu URL injectat dinamic din `package.json.repository.url` (similar cu `appVersion`). Adaugă test simplu: `grep -r "anthropics/claude-replay" template/ src/ === 0`.
- **Efort:** 1 h. [AUDIT_WEB.md § Lipsuri](AUDIT_WEB.md#lipsuriobservații)

---

## P1 — Important fixes

### P1.1 — CHANGELOG.md decalat 0.5→0.8.1 (5 versiuni nedocumentate)
- **Problemă:** `CHANGELOG.md:3` se oprește la `0.4.1`. Versiunile 0.5, 0.6, 0.7, 0.8.0, 0.8.1 (dashboard, account switcher, projects browser, SQLite cache, lazygit, terminal WebSocket, SSE live updates, claude-outlook, claude-yahoo) nu sunt documentate.
- **File:** `CHANGELOG.md`
- **Soluție:** Reconstituie din `git log` pe `package.json` (`git log -p package.json`) — versiunile sunt în commit-uri. Adaugă secțiuni `0.5.0`, `0.6.0`, `0.7.0`, `0.8.0`, `0.8.1`.
- **Efort:** 2 h. [AUDIT_WEB.md § Lipsuri](AUDIT_WEB.md#lipsuriobservații), [AUDIT_DIFF.md § Decalaje](AUDIT_DIFF.md#decalaje-de-versiune-și-sincronizare)

### P1.2 — README nu acoperă flag-urile noi 0.5-0.8.1
- **Problemă:** README documentează CLI bine, dar nu menționează: subcomanda `editor` explicit, terminal/lazygit integration, dashboard, project browser, account switcher, SQLite cache, SSE events, accounts `claude-outlook`/`claude-yahoo`. Are 34 secțiuni dar acoperă fluxul vechi 0.4.x.
- **File:** `README.md`
- **Soluție:** Adaugă secțiunile `## Dashboard`, `## Terminal integration` (lazygit), `## Multi-account support`, `## Caching`. Trimite la `/docs` rută servită pentru detalii.
- **Efort:** 3 h.

### P1.3 — OG image default depinde de un repo extern care poate dispărea
- **Problemă:** `src/renderer.mjs:130` are `ogImage` default `https://es617.github.io/claude-replay/og.png`. Dacă owner-ul (es617) face repo private sau șterge GitHub Pages, toate replay-urile generate fără `--og-image` arată broken OG card.
- **File:** `src/renderer.mjs:130`
- **Soluție:** Două opțiuni — (a) embed image-ul ca base64 data URL (cost: +~10KB per export); (b) host o copie pe un domeniu controlat de proiect. Recomand (b) cu fallback empty-string dacă lipsește, plus warning în README.
- **Efort:** 1 h.

### P1.4 — Repo URL inconsistent între `package.json` și README badges
- **Problemă:** `package.json:43` declară `es617/claude-replay`. README folosește același URL pentru badges și demo gif. Dar git remote local poate diferi de owner (vezi git user `matthew` din session). Care e canonical?
- **File:** `package.json:43`, `README.md:17,112,453`
- **Soluție:** Confirmă owner-ul (verifică cu `git remote -v`) și actualizează `package.json.repository.url`, `package.json.bugs.url` (lipsește), `package.json.homepage` (lipsește). Adaugă explicit `bugs` și `homepage` în `package.json`.
- **Efort:** 0.5 h.

### P1.5 — Dead code: `isFavorite` și `getTagsForSession` importate dar neutilizate
- **Problemă:** `src/editor-server.mjs:24-25` definește variabilele fallback pentru `isFavorite` și `getTagsForSession`, dar acestea nu sunt apelate în niciun handler API. Tag-urile per-sesiune nu sunt expuse în UI; favoritele se verifică client-side prin lista globală.
- **File:** `src/editor-server.mjs:24-25`
- **Soluție:** Două căi: (a) elimină definițiile dacă featurile nu sunt planificate; (b) expune `GET /api/tags?path=X` și `GET /api/favorites/check?path=X` și folosește-le în dashboard pentru per-row state.
- **Efort:** 1.5 h (calea b) sau 0.25 h (calea a). [AUDIT_WEB.md § Lipsuri](AUDIT_WEB.md#lipsuriobservații)

### P1.6 — `/api/render-replay` ruta dublată în routing
- **Problemă:** `src/editor-server.mjs:1604-1606` rutează explicit `/api/render-replay` apoi fallback-ul `1608` `pathname.startsWith("/api/")` îl preia oricum. Redundant, dar inofensiv.
- **File:** `src/editor-server.mjs:1604-1610`
- **Soluție:** Șterge blocul `if (pathname === "/api/render-replay" ...)` de la `1604-1606`. Verifică test e2e că rendering iframe continuă să funcționeze.
- **Efort:** 0.25 h. [AUDIT_WEB.md § Lipsuri](AUDIT_WEB.md#lipsuriobservații)

### P1.7 — Limita hard-coded MAX_INPUTS=20 fără override
- **Problemă:** `bin/claude-replay.mjs:161` limitează la 20 inputs concatenate. Util pentru protecție, dar nu e configurabil. Power-users care vor să concateneze 30 sesiuni eșuează cu mesaj rigid.
- **File:** `bin/claude-replay.mjs:161-165`
- **Soluție:** Flag `--max-inputs N` (default 20, max 200 pentru safety). Plus warning în stderr peste 50 ("This may produce a large HTML file").
- **Efort:** 1 h. [AUDIT_WEB.md § Lipsuri](AUDIT_WEB.md#lipsuriobservații)

### P1.8 — Help CLI: lipsesc `--host`, `--description` poziție inconsistentă
- **Problemă:** Help-ul (`bin/claude-replay.mjs:82-127`) nu listează `--host` (deși există ca opțiune la `bin/claude-replay.mjs:18`). `--description` apare imediat după `--title` în help, dar lista de opțiuni e altă ordine vs README.
- **File:** `bin/claude-replay.mjs:82-127`
- **Soluție:** Adaugă `--host ADDR` (default 127.0.0.1) sub `--port`. Sortează help-ul în secțiuni clare: Server, Output, Selection, Timing, Theming, Redaction, Meta, Bookmarks, Info.
- **Efort:** 0.5 h.

### P1.9 — Lipsa exit-code consistent pe error paths CLI
- **Problemă:** CLI iese cu `process.exit(1)` în multe locuri (`bin/claude-replay.mjs:51,65,138,141,...`) cu același cod indiferent de categoria erorii (invalid flag, file not found, parse error). Tooling-ul care apelează `claude-replay` nu poate diferenția.
- **File:** `bin/claude-replay.mjs` (multiple locații)
- **Soluție:** Adoptă convenție Unix: `2` pentru usage error (invalid flag), `1` pentru runtime error (file not found, parse error), `0` success. Document în README/help.
- **Efort:** 1 h.

### P1.10 — Endpoint-uri API fără validare strictă pe shape body
- **Problemă:** `src/editor-server.mjs:1013-1023` (`/api/edit`) nu verifică tipurile `sessionId` (string), `turnIndex` (number), `user_text` (string). Un POST cu `turnIndex: "abc"` produce `find(t => t.index === "abc")` → undefined → 404 generic, fără mesaj clar. Similar pentru alte handlere.
- **File:** `src/editor-server.mjs` (toate `handleApi` branches)
- **Soluție:** Mic helper `requireFields(body, schema)` care întoarce 400 cu mesaj precis. Nu folosi runtime validator extern (zero deps); doar typeof checks.
- **Efort:** 2 h.

---

## P2 — Polish / Nice-to-have

### P2.1 — Comentariu eronat în AUDIT despre `spinnerVerbs.mjs`
- **Observație:** Auditul (`AUDIT_WEB.md:455`) zice că `spinnerVerbs.mjs` "nu e folosit la UI". Verificat: e importat în `src/editor-server.mjs:13` și injectat ca JSON în template-uri la `1441`. Audit-ul e desincronizat; codul e corect.
- **File:** `docs/AUDIT_WEB.md:455` (doar nota)
- **Soluție:** Acțiune simbolică — doar update la audit. Nicio modificare în cod.
- **Efort:** 0.25 h.

### P2.2 — `spinnerVerbs.mjs` dependent de repo extern pentru update-uri
- **Problemă:** `src/spinnerVerbs.mjs:1` are comentariul `// Auto-extracted from theclaude-mtw/src/constants/spinnerVerbs.ts`. Dependent silent de un repo extern — dacă cineva vrea să adauge verb nou, nu știe de unde să copie.
- **File:** `src/spinnerVerbs.mjs:1`
- **Soluție:** Adaugă în `scripts/` un `update-spinner-verbs.mjs` documentat (sau pune lista in-place fără referință externă, marchează clar că e o copie inertă).
- **Efort:** 0.5 h.

### P2.3 — Sync I/O pe `/api/sessions` și `/api/projects`
- **Problemă:** `discoverSessions` (`src/editor-server.mjs:329-430`) folosește `readdirSync` recursiv. Pentru users cu 50+ proiecte și mii de sesiuni, blochează event loop la fiecare GET (deși are cache mtime per fișier prin SQLite).
- **File:** `src/editor-server.mjs:329-430`, `569-611`
- **Soluție:** Convert la `readdir`/`stat` async (`fs.promises`). Pe deasupra, cache rezultatul `discoverSessions()` pentru 5 secunde (memo cu TTL) — invalidat de SSE watcher la `sessions-changed`.
- **Efort:** 3 h.

### P2.4 — Placeholder collision posibil cu input arbitrar
- **Problemă:** `src/renderer.mjs:152-162` injectează placeholder-uri stil `/*PAGE_TITLE*/` cu `replaceAll`. Plasarea ordonată previne coliziuni cu `TURNS_DATA`, dar dacă un user folosește `--title "/*TURNS_DATA*/"` sau în `description`, va injecta `/*TURNS_DATA*/` în output (care apoi NU mai e înlocuit pentru că e după replaceAll-ul lui).
- **File:** `src/renderer.mjs:152-162`
- **Soluție:** Verifică toate stringurile user-supplied (`title`, `description`, `ogImage`, `userLabel`, `assistantLabel`) că nu conțin pattern `/\*[A-Z_]+\*/`. Refuză sau escape. Alternativ: schimbă sentinels la token-uri imposibil de tipăit (ex. UUID-uri generate la fiecare render).
- **Efort:** 1.5 h.

### P2.5 — Log levels inconsistente
- **Problemă:** Server folosește `console.log` pentru atât info ("Attaching terminal WebSocket...") cât și succes (`Terminal WebSocket attached successfully`), `console.error` pentru erori. Nu există un logger structurat; debugging pe Docker e greu.
- **File:** `src/editor-server.mjs:1625,1627,1629,1638,1642,1643`
- **Soluție:** Mic logger (`src/log.mjs`) cu `info`/`warn`/`error` + flag `--quiet`. Zero dependencies. Format text simplu cu `[INFO]` prefix.
- **Efort:** 1 h.

### P2.6 — `Map<sessionId, ...>` din `editor-server` crește fără limită
- **Problemă:** `src/editor-server.mjs:38` ține un `sessions` Map care e populat la fiecare `/api/load`. Sesiuni încărcate și abandonate (browser închis) rămân în memorie indefinit. Pentru un proces server long-running, leak.
- **File:** `src/editor-server.mjs:38-39`
- **Soluție:** LRU simplu cu max 20 sesiuni active (eject cel mai vechi accesat). Track `lastAccessed` la fiecare API hit care folosește `sessionId`.
- **Efort:** 2 h.

### P2.7 — `extract.mjs` parse regex fragil
- **Problemă:** `src/extract.mjs:50` folosește regex `/await\s+[\w$]+\("/g` pentru a găsi blob-urile. Dacă build-time minifier-ul schimbă pattern-ul (ex. transformă în chain Promise), extract eșuează. Are deja un fix pentru minificat (audit menționează 0.4.1) dar pattern-ul e fragile.
- **File:** `src/extract.mjs:48-69`
- **Soluție:** Adaugă sentinels în template (ex. `<!-- TURNS_BLOB_START --><script>...<!-- TURNS_BLOB_END -->`) astfel încât extract să găsească prin marker, nu prin pattern JS.
- **Efort:** 2 h.

### P2.8 — `applyPacedTiming` modifică turns in-place
- **Problemă:** `src/parser.mjs:645` (referit în CLI și editor-server) modifică obiectele turn primite. Caller-ul nu se așteaptă neapărat la mutație. La `bin/claude-replay.mjs:298` și `src/editor-server.mjs:239` se apelează direct pe array-uri.
- **File:** `src/parser.mjs:645`
- **Soluție:** Documentează clar prin JSDoc că modifică in-place, sau întoarce array nou. Recomand a doua opțiune (clone) — caller-ii deja clone-ează turnurile în `prepareTurns`.
- **Efort:** 0.5 h.

### P2.9 — `Number.isFinite(rawSpeed)` dar nu și `Number.isFinite(parseFloat(...))` CLI
- **Problemă:** `bin/claude-replay.mjs:301` face `parseFloat(values.speed) || 1.0`. Dacă user dă `--speed NaN`, `parseFloat` → NaN, OR-ul → 1.0 — corect. Dar `--speed 0` → 0 OR 1.0 → 1.0, ascunde un input deliberat (deși 0 oricum e clampat în renderer). Pentru consistență cu renderer-ul, mai bine raise error.
- **File:** `bin/claude-replay.mjs:301`
- **Soluție:** Validează explicit: `if (!Number.isFinite(speed) || speed <= 0) error`.
- **Efort:** 0.25 h.

### P2.10 — Lipsa `package-lock.json` sub controlul mai strict
- **Problemă:** `package-lock.json` există dar nu e clear dacă e gitignored. Verificat: nu e (e prezent în repo). OK. Dar nu există `npm ci` în CI / Dockerfile (folosește `npm install`), ceea ce poate genera lockfile drift.
- **File:** `Dockerfile:16`
- **Soluție:** `RUN npm ci` în loc de `npm install` în Dockerfile.
- **Efort:** 0.25 h.

---

## Improvements pe arie funcțională

### CLI

- **Pipe detection pentru stdout (a)**: la CLI fără `-o`, output-ul merge pe stdout cu HTML brut. Dacă stdout e TTY (`process.stdout.isTTY`), warn user-ul și sugerează `-o file.html`. **Efort:** 0.5 h. **File:** `bin/claude-replay.mjs:404-408`.
- **Format JSON alternativ ca output**: există `extract` invers, dar nu există `--format json` ca alternativ la HTML (util pentru tooling). **Efort:** 1.5 h. **File:** `bin/claude-replay.mjs:379-409` + nou flag `--format html|json|md`.
- **Session chaining edge: timestamps amestecate**: la concatenare (`bin/claude-replay.mjs:260-270`), dacă unele sesiuni au timestamps și altele nu, comportamentul e command-line order. E corect dar nu warn user-ul. **Efort:** 0.5 h.
- **`--theme-file` watch mode pentru dev**: la regenerare repetată, edit-ul în `theme.json` cere re-run. Flag `--watch` care reface output la fiecare modificare. **Efort:** 2 h.
- **`--no-open` explicit**: în Docker / CI implicit nu se vrea `open`. Editorul deschide automat browser-ul la start (`editor-server.mjs:1644-1648`). Adaugă `--no-open` flag și branch `if (process.env.DOCKER || !process.stdout.isTTY) open=false` automat. **Efort:** 0.5 h. **File:** `src/editor-server.mjs:1644-1648`.

### Editor server

- **CSRF doar prin Origin e fragile**: `src/editor-server.mjs:915-925` respinge cross-origin pe baza header-ului Origin, dar nu verifică nimic dacă Origin lipsește. Adaugă în plus un token CSRF rotativ injectat în HTML (`/*CSRF_TOKEN*/`) și verificat în handle pentru POST-uri. **Efort:** 3 h.
- **Error responses standardizate**: răspunsurile error variază (`error(res, "Unknown session", 404)` vs `error(res, "Missing path")`). Standardizează: `{ error: { code, message, details } }` (similar Problem Details RFC 7807 light). **Efort:** 2 h.
- **Paginare pe `GET /api/sessions`**: discoverSessions returnează tree întreg. Pentru users cu 100+ proiecte, response > 1MB. Suport `?page=N&limit=M` (deja există pe `/api/projects/details`, generalizează). **Efort:** 2 h. **File:** `src/editor-server.mjs:928-935`.
- **Rate limiting pe `/api/search` și `/api/preview`**: search face I/O pe până la 30 fișiere per request (`editor-server.mjs:1189`). Un loop de POST-uri (legitim sau atac) saturează disk. Token bucket simplu in-memory (10 req/sec/IP). **Efort:** 2 h.
- **Health endpoint `/healthz`**: pentru Docker healthcheck, expune `GET /healthz` care întoarce 200 cu `{version, uptime, sqliteAvailable}`. **Efort:** 0.5 h.
- **MAX_BODY_SIZE=10MB hardcoded**: `src/editor-server.mjs:119` cap rigid. Pentru sesiuni mari (>10MB JSONL), `/api/preview` eșuează cu "Request body too large". Configurabil prin env `CLAUDE_REPLAY_MAX_BODY`. **Efort:** 0.5 h.

### Player HTML

- **Accessibility zero în `player.html`**: 0 attribute `aria-*`/`role=`/`tabindex` în 2725 linii (`grep -c "aria-" template/player.html === 0`). Pentru screen readers e inaccesibil. Adaugă: `role="region"` pe controls bar, `aria-label` pe play/next/prev/speed, `aria-live="polite"` pe progress text, `tabindex` pentru focus management. **Efort:** 3 h. **File:** `template/player.html:1030-1095`.
- **Modularizare 2725 linii JS**: player-ul include CSS+JS într-un singur fișier HTML. Pentru maintainability, split-uire în `template/player/{styles.css, render.js, player.js, markdown.js}` și concat la build-time în `scripts/build-template.mjs`. **Efort:** 5 h.
- **Deep linking pe bookmarks**: deep links `#turn=N` sunt acoperite (test Playwright). Extinde: `#bookmark=label` care navighează la bookmark numit. **Efort:** 1.5 h.
- **URL hash pe state preview**: split-bar position, expanded blocks etc. nu sunt persistate. Salvează în `localStorage` cheie pe URL hash. **Efort:** 2 h.
- **Print/PDF CSS layout**: print dialog generează rezultat OK dar marginile sunt large. Adaugă `@media print` cu margin 0.5cm și hide controls bar. **Efort:** 1 h.
- **Tool grouping threshold explicit**: web grupează toate `tool_use` consecutive (audit menționează inconsistență cu Swift care folosește ≥5). Aliniere cu Swift sau document explicit threshold ca constant. **Efort:** 1 h. **File:** `template/player.html:1547-1559`.

### Parser

- **Robustețe pe input malformat**: `parseJsonl` (`src/parser.mjs:89-101`) skip-uiește silent linii invalide. Dacă **toate** liniile sunt invalide, returnează turn-uri goale fără warning. Adaugă counter "skipped invalid lines" și log la stderr. **Efort:** 1 h.
- **Edge cases Codex** suportate (vezi `test/fixture-codex-edges.jsonl`), dar nu sunt teste pentru: timestamp absent, `exec_command` cu cmd gol, `apply_patch` cu format malformat (missing `*** End File:`). **Efort:** 2 h.
- **Versionare format Claude Code**: parser-ul nu verifică version field. Dacă Anthropic schimbă schema (ex. adaugă block kind nou), parser-ul ignoră silent (`if (b.type === ...)` else nimic). Adaugă warning pentru kinds necunoscute. **Efort:** 1 h. **File:** `src/parser.mjs:182-235`.
- **Streaming pentru sesiuni mari**: `parseTranscript` citește întreg fișierul în memorie (`readFileSync`). Pentru sesiuni > 100MB, ineficient. Stream cu `readline.createInterface`. **Efort:** 3 h. **File:** `src/parser.mjs:529`.

### Renderer

- **Brotli alternative**: `deflate+base64` dă ~60-70% reducere. Brotli ar fi ~75-80% (Node `zlib.brotliCompressSync`). Flag `--compress brotli|deflate` cu deflate default pentru compatibilitate cu `extract`. **Efort:** 2 h. **File:** `src/renderer.mjs:35-37`.
- **Template engine prin AST**: placeholders `/*NAME*/` sunt fragile (vezi P2.4). Alternative: HTML comments (`<!-- @PLACEHOLDER name -->`) procesate strict înainte de minify. **Efort:** 4 h (mai mult dacă vrem să rămână compatibilitate).
- **Validare placeholder coverage**: build script (`scripts/build-template.mjs`) verifică placeholder-urile, dar `render` la runtime nu validează că toate placeholder-urile au fost înlocuite (poate genera HTML cu `/*PAGE_DESCRIPTION*/` literal). Add assertion. **Efort:** 0.5 h.

### Redaction

- **False positives pe `hex_token`**: pattern `\b[0-9a-fA-F]{40,}\b` capturează commit SHA-uri git (40 hex). Util pentru secrete dar redactează și hash-uri vizibile în output. Adaugă blacklist context (precedat de "commit "/"sha "). **Efort:** 1.5 h. **File:** `src/secrets.mjs:48`.
- **Custom patterns prin config file**: există `--redact "search=replacement"` literal, dar nu există custom regex patterns. Adaugă `--redact-file FILE` cu YAML/JSON care extinde `SECRET_PATTERNS`. **Efort:** 2 h.
- **Regex performance pe text mare**: 11 patterns × cleanup la fiecare string × walk recursiv pe object. Pentru sesiuni cu 1000+ turns × 10 blocks/turn × 5KB text, costul redacției e considerabil. Profilare + posibil consolidare în mega-regex alternation. **Efort:** 3 h.
- **Test edge: secret la limita fișier**: pattern `private_key` cere `BEGIN..END` complete. Dacă fișierul JSONL e truncated (BEGIN dar nu END), pattern nu capturează → leak. Adaugă test + fallback heuristic. **Efort:** 1 h.

### Persistență (SQLite)

- **Migrations versionate**: `src/db.mjs:30-72` folosește `CREATE TABLE IF NOT EXISTS`. La schema change (adăugare coloană nouă), tabela veche nu se actualizează. Adaugă table `_schema_version` și migrations list cu numere. **Efort:** 2 h.
- **Vacuum periodic**: cache.db crește indefinit dacă session_meta/stats acumulează. Adaugă `VACUUM` la startup dacă size > 100MB sau săptămânal. **Efort:** 1 h.
- **Indexes lipsă**: `session_stats` are doar primary key pe `path`. Pentru queries `WHERE file_mtime > X` (eventual cleanup), index lipsă. Adaugă `CREATE INDEX idx_stats_mtime`. **Efort:** 0.25 h. **File:** `src/db.mjs:49-54`.
- **Raportare graceful când better-sqlite3 nu se instalează**: `src/editor-server.mjs:16` are fallback la no-op. UI nu primește semnal că persistența e dezactivată (favorite-uri par "salvate" dar dispar la restart). Expune `GET /api/cache-info` returnează `{ enabled: false, reason: "..." }` și UI afișează warning. **Efort:** 1.5 h.
- **Lock contention**: SQLite WAL e thread-safe, dar pe multiple requests concurente cu writes (setCachedMeta), pot exista locking warnings. Profilare needed. **Efort:** 2 h (dacă apare problema).

### Terminal / Lazygit

- **Security — command injection în query param `cmd`**: `src/terminal.mjs:42,50` ia `cmd` din `?cmd=...` și-l rulează ca `${SHELL} -c <cmd>`. Dacă cineva ocolește CSRF check (WebSocket nu are check Origin!), poate executa orice. **CRITIC pentru deployment care expune portul.** Whitelist hard: `cmd ∈ ["lazygit", "shell"]`. **Efort:** 1.5 h. **File:** `src/terminal.mjs:42`.
- **WebSocket CSRF lipsește**: `attachTerminalWs` (`src/terminal.mjs:23-128`) nu verifică Origin la upgrade. Un site cross-origin poate deschide WS pe `127.0.0.1:7331`. Adaugă check Origin similar cu API. **Efort:** 1 h.
- **Restricționarea cwd**: `cwd = url.searchParams.get("path") || process.env.HOME`. Nu există assertUnderHome. Path-uri arbitrare permit lazygit să operate pe `/etc/.git` (improbabil dar posibil). Adaugă check. **Efort:** 0.5 h. **File:** `src/terminal.mjs:41`.
- **Reconnect logic**: WS-ul nu reconectează la close. Pe rețea lentă/Docker restart, user trebuie să refresh page. Adaugă auto-reconnect cu backoff în `lazygit.html`. **Efort:** 2 h.
- **TERM/COLORTERM hard-coded**: `terminal.mjs:61-62` setează `xterm-256color`. Pentru iTerm2 sau Kitty users, ar prefera `xterm-kitty`. Permit override via env. **Efort:** 0.5 h.

### Docker / Distribuție

- **Image size**: `node:22-alpine` + python3/make/g++ → ~400MB. Multi-stage build cu copy doar `node_modules` la runtime image → ~150MB. **Efort:** 2 h. **File:** `Dockerfile`.
- **Multi-arch build**: `Dockerfile:8` downloadează `lazygit_Linux_x86_64`. ARM64 (Apple Silicon Docker Desktop, AWS Graviton) eșuează. Folosește `${TARGETARCH}` BuildKit variable. **Efort:** 1.5 h.
- **Healthcheck Docker**: `docker-compose.yml` nu are healthcheck. Adaugă `HEALTHCHECK CMD curl -f http://localhost:7331/healthz || exit 1` (după P0/health endpoint). **Efort:** 0.5 h.
- **Versionare imagine**: `docker build` actual e mereu `latest`. Tag explicit cu version din `package.json`. Push automat în `.github/workflows/`. **Efort:** 2 h.
- **Secrets handling**: docker-compose mountează `$HOME` rw + `.claude*` ro. Documentează limpede care fișiere se citesc, care se scriu (lazygit poate scrie git commits). Adaugă `SECURITY.md` cu surface area. **Efort:** 1 h.
- **`npm ci` în loc de `npm install` în Dockerfile**: deterministic builds. **Efort:** 0.25 h.

### Documentation

- **README missing flags** (vezi P1.2).
- **CHANGELOG resync** (vezi P1.1).
- **Docker compose recipes**: exemple pentru: (a) reverse proxy în spatele nginx (HTTPS), (b) Caddy auto-TLS, (c) Tailscale exposure (read-only access pe rețea privată), (d) doar dashboard fără terminal/lazygit (override CMD). **Efort:** 2 h.
- **API docs**: niciun OpenAPI/Swagger pentru API-uri. Pentru integratori (third-party tools), publică un `docs/API.md` cu fiecare endpoint, params, response shape. **Efort:** 3 h.
- **CONTRIBUTING.md lipsește**: instrucțiuni pentru contribuții (cum se rulează tests, cum se build-uiește template). **Efort:** 1 h.
- **HUMAN-SMOKE-TEST.md și AGENT-SMOKE-TEST.md** sunt în `test/` dar nu referite în README. Add link. **Efort:** 0.25 h.

---

## Testing improvements

- **Coverage pentru `src/terminal.mjs`**: 0 unit tests, 0 e2e. Greu de testat (necesită PTY), dar mockable cu `child_process`. Add `test-terminal.mjs` care verifică: whitelist cmd, restricționare cwd, mesaj erorile. **Efort:** 3 h.
- **Coverage pentru `src/db.mjs`**: 0 tests. Add `test-db.mjs` cu fixture sqlite. **Efort:** 2 h.
- **e2e pentru terminal/lazygit**: lipsesc complet. Add Playwright spec care deschide `/lazygit?path=...`, verifică conexiune WS și că footer arată versiunea corectă. **Efort:** 2 h.
- **e2e pentru SSE `/api/events`**: nu sunt testate. Mock cu EventSource și verifică heartbeat. **Efort:** 2 h.
- **Snapshot tests pentru renderer**: `test-renderer.mjs` verifică placeholder safety dar nu compară HTML output vs snapshot stocat. Add `__snapshots__/` și diff-uire pe regressions. **Efort:** 2 h.
- **Coverage parser cu sesiuni reale**: fixture-urile sunt sintetice; coverage pe sesiuni reale (anonimizate) ar prinde edge cases. Add `test/fixture-real-anonymized/` cu 2-3 sesiuni transcripts curate. **Efort:** 2 h.
- **CI matrix Node 18/20/22**: actualmente nu e clear ce versiuni sunt testate (`engines: node >=18`). GitHub Actions matrix. **Efort:** 1 h. **File:** `.github/workflows/` (verifică ce există).
- **Performance regression tests**: bench rendering pentru 100/500/1000 turns. Detectează slow-downs introduse de modificări viitoare. **Efort:** 2 h.

---

## Securitate

Audit dedicat:

- **CSRF actual**: doar Origin check (`editor-server.mjs:915-925`). Vulnerabil pentru: (a) clienti fără Origin (curl, Postman), (b) atacuri DNS rebinding (Origin pare legitim). **Fix:** token CSRF rotativ + check că `Sec-Fetch-Site: same-origin` sau `Host: 127.0.0.1`. **Efort:** 3 h.
- **Path traversal `/api/browse`**: vezi P0.2 (symlink bypass).
- **Path traversal `/api/render-replay`, `/api/transcript`, `/api/export-md`, `/api/session-stats`**: toate folosesc `assertUnderHome` care e susceptibil la symlinks (vezi P0.2). Singura fix-uire necesară e în `assertUnderHome`.
- **Command injection în terminal spawn**: vezi Terminal / Lazygit section. **Critic dacă portul e expus.**
- **WebSocket fără Origin check**: vezi Terminal section.
- **Validation pe input-uri API**: vezi P1.10.
- **`/api/open` execută aplicații**: vezi P0.3.
- **MAX_BODY_SIZE bypass**: header `Content-Length` neverificat. Dacă client trimite Transfer-Encoding chunked > 10MB, check `size += c.length` prinde, dar nu există abort la primul chunk. OK probabil.
- **SSE — keep-alive descopere uptime**: heartbeat la 30s, dacă cineva monitorizează `/api/events` poate determina precis când server-ul restartează. Trivial leak.
- **Dependențe `better-sqlite3`/`node-pty`/`ws`/`@xterm/*`**: rulează `npm audit` periodic în CI; actualmente nu e clear dacă există workflow. **Efort:** 1 h pentru CI workflow.
- **Output HTML self-contained — XSS pe input transcripts**: `template/player.html` randează markdown din `block.text` cu `renderMarkdown` (`player.html:1231`). Dacă markdown-ul permite `<script>` injection, HTML-ul exportat e XSS-vulnerable când e shared. Verifică `renderMarkdown` că escape-uiește HTML. **Efort:** 2 h (audit + fix dacă apare).

---

## Roadmap propus

Trei sprinturi mici, fiecare 1-2 săptămâni, cumulativ acoperă P0 + P1 + parte din P2 și security.

### Sprint 1 (1 săptămână) — "Stabilize"
- P0.1 (LICENSE restore)
- P0.2 (assertUnderHome hardening) + Terminal/Lazygit security (command injection whitelist + WS CSRF + cwd check)
- P0.3 (`/api/open` whitelist)
- P0.5 (help modal URL)
- P1.1 (CHANGELOG resync)
- P1.4 (repo URL alignment)
- Quick wins: P1.6 (route dedupe), P2.10 (`npm ci`), P2.1 (audit note correction)

**Efort sprint:** ~10 h ≈ 1.5 zile-om.

### Sprint 2 (1 săptămână) — "Polish & UX"
- P0.4 (template caching)
- P1.2 (README update)
- P1.3 (OG image fix)
- P1.5 (dead code: tags + favorites wiring sau cleanup)
- P1.7 (MAX_INPUTS configurable)
- P1.8 (help CLI consistency)
- P1.9 (exit codes)
- P2.4 (placeholder collision guard)
- P2.5 (logger structured)

**Efort sprint:** ~13 h ≈ 2 zile-om.

### Sprint 3 (2 săptămâni) — "Reliability & Future-proof"
- P1.10 (API input validation)
- P2.3 (async I/O + cache TTL)
- P2.6 (session LRU)
- Persistență: migrations versionate, vacuum, indexes
- Docker: multi-arch + healthcheck + image size
- Testing: terminal + db + SSE coverage
- Securitate: CSRF token rotativ + XSS audit pe `renderMarkdown`

**Efort sprint:** ~25 h ≈ 3.5 zile-om.

**Total roadmap acoperit:** ~48 h ≈ 7 zile-om (din 8-12 estimate total). Restul (P2.2, P2.7, P2.8 etc.) — backlog.

---

## Out of scope (proiecte mari separate)

Următoarele ar fi proiecte majore, nu improvements:

- **Chat live (paritate cu Swift `Chats` tab)** — necesită integrare `@anthropic-ai/claude-agent-sdk`, sidecar Node sau proxy. Efort estimat: 2-4 săptămâni. Recomandare: rămâne Swift-only oficial (vezi [AUDIT_DIFF.md § Recomandări 9](AUDIT_DIFF.md#recomandări-pentru-paritate-completă)).
- **Mobile app** — iOS/Android native viewing pentru replay-uri. Player HTML-ul actualele e responsive dar pas e funcționalitatea CLI/editor.
- **Collaborative editing** — multi-user concurrent pe același editor session. Necesită Yjs/Automerge + reconciliation. Backend state Map → CRDT.
- **Integrare directă cu Claude API** — generare de transcripts (nu doar replay). Out of scope pentru un viewer.
- **Sync cloud / sharing platform** — host replay-uri publice cu URL-uri scurte. Necesită backend separat (S3, R2, etc.) și autentificare.
- **Plugin system pentru player** — extensie HTML out-of-the-box (ex. custom block renderers). Necesită API formal și sandbox.
- **VS Code extension** — replay în panou VS Code direct, fără export HTML.
- **Self-hosted multi-tenant** — pentru echipe care vor să host server cu autentificare. Necesită OAuth, RBAC.

Pentru toate cele de mai sus: deschideți issue separat pentru discuții de design înainte de implementare.
