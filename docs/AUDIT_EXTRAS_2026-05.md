# SWIFT-Only Extras Verification Audit — 2026-05

Auditor: automated trace of each claimed Swift-only "extra" from UI → ViewModel →
Service → effect, cross-checked against a clean build + full test run. The two
prior audit docs (`AUDIT_DIFF_V2.md`, `AUDIT_SWIFT_V2.md`) were NOT trusted; every
claim below was re-derived from source.

App: `swift/Claude-MTW-Replay` (SwiftUI + MVVM). Companion web app: `src` (v0.8.1).

## Executive summary

**Verdict: the extras are overwhelmingly real.** Of the 17 claimed Swift-only
features traced, **14 are fully implemented and wired end-to-end (✅)**, **3 are
partial (🟡)**, and **0 are stubs or dead code (❌)**.

The headline extra — live chat with Claude via a Node sidecar — is genuinely
end-to-end: a real `sidecar.js` shells out to the installed
`@anthropic-ai/claude-agent-sdk` (v0.1.77 present in `node_modules`), the Swift
`ClaudeAgent` actor spawns it, pumps line-delimited JSON both ways, and an
**integration test actually launches the sidecar and round-trips messages** (it
passed, not skipped, because `node` is on this host).

The 3 partials are **Telemetry** (records to stderr only — "No backend yet"),
**CrashReporter** (subscribes to MetricKit for real but persists nothing and
`recentDiagnostics()` returns `[]`), and **attachments** (text/code is genuinely
inlined into the prompt, but images/PDFs are passed as a path reference with a
`TODO` to switch to image blocks once the wire protocol grows binary support).
None of these are fake — they are honestly-scoped partials with the gap documented
in-code.

**Build: SUCCEEDED** (0 errors, 406 warnings). **Tests: 109 executed, 0 failures,
3 skipped** (the 3 skips are WebKit-dependent HTMLRenderer cases).

## Status table

| # | Extra | Status | Evidence |
|---|-------|--------|----------|
| 1 | Live chat via Node sidecar | ✅ | `sidecar/sidecar.js:145-375` real `query()` loop; `Services/ClaudeAgent.swift:94-167` spawns `node sidecar.js`, pumps stdio; `Services/SidecarLocator.swift:41-70` resolves bundled script + node/claude binaries; `ViewModels/ChatViewModel.swift:123-202` start/send. Skeleton round-trip test passes (`Tests/ClaudeAgentSkeletonTests.swift`). SDK v0.1.77 in `sidecar/node_modules`. Sidecar copied into built `.app/Contents/Resources/Sidecar/` (verified). |
| 2 | Chat transcript persistence | ✅ | `Persistence/ChatTranscriptEntity.swift` `@Model`; `DataStore.swift:150-203` upsert/fetch; `ChatViewModel.swift:572-601` debounced 1s persist on each turn. |
| 3 | Conversation forking / branch list | ✅ | `Services/SessionForker.swift:51-106` real JSONL truncation at N-th user turn; `DataStore.swift:244-286` `forkSession`/`getBranches` (parent + root tracking); `ChatViewModel.swift:299-307` `forkFromTurn`; `Views/Chats/ChatBranchListView.swift` lists + navigates. Wired from `ChatView.swift:335`. |
| 4 | MCP servers integration | ✅ | `Models/MCPServerSpec.swift`; `Services/MCPServerStore.swift:18-56` load/save/`activeServers()` → SDK dict; `ChatViewModel.swift:156-161` serialises to JSON; forwarded as `--mcp-servers` (`ClaudeAgent.swift:283-285`) → parsed in `sidecar.js:301-310` into `options.mcpServers`. UI: `MCPServersSettingsView.swift` mounted in `SettingsView.swift:104`. |
| 5 | Model picker (Opus/Sonnet/Haiku + pricing) | ✅ (note) | `Views/Chats/ChatModelPickerView.swift:23-56`; binds `vm.selectedModel`, respawns via `respawnWithNewOptions`; forwarded as `--model` (`ClaudeAgent.swift:274-276`) → `options.model` (`sidecar.js:288-290`). Mounted `ChatView.swift:82`. NOTE: model ids (`claude-opus-4-7` etc.) are passed verbatim to the SDK; their validity depends on the SDK accepting them — not validated app-side. |
| 6 | System prompt editor | ✅ (note) | `Views/Chats/SystemPromptSheet.swift:49-57` writes `vm.systemPromptOverride` + respawns; `--custom-system-prompt` (`ClaudeAgent.swift:277-279`) → `options.customSystemPrompt` (`sidecar.js:294-296`). NOTE: the two "Include CLAUDE.md / MEMORY.md context" toggles are UI-only hints (`ChatViewModel.swift:71-76` says "reserved for the sidecar"); they don't yet change the outbound request. |
| 7 | Tool whitelisting UI | ✅ | `Views/Chats/ChatToolPickerView.swift:24-56`; `--allowed-tools`/`--disallowed-tools` (`ClaudeAgent.swift:265-269`) → `options.allowedTools` (`sidecar.js:279-284`); persisted via `DataStore.setEnabledTools` (`ChatViewModel.swift:607-612`). Mounted `ChatView.swift:106`. |
| 8 | Slash commands from `.claude/commands/*.md` | ✅ (minor) | `Services/SlashCommandService.swift:11-67` scans project + user dirs, parses front-matter; `Views/Chats/SlashCommandPickerView.swift`; loaded + filtered in `ChatInputBarView.swift:40-52,290-303`. MINOR: `$ARGUMENTS` always expands empty (`cmd.expanded(args: "")`, ChatInputBarView.swift:298) — trailing tokens aren't piped through yet. |
| 9 | Permission management UI | ✅ | `Models/PermissionDecision.swift`; `Persistence/PermissionDecisionEntity.swift`; sidecar `canUseTool` bridge (`sidecar.js:317-340`) ↔ `ClaudeAgent.sendPermissionResponse` (`ClaudeAgent.swift:182-191`); `ChatViewModel.swift:401-435` cache-check + record; `Views/Chats/PermissionAlertView.swift` modal mounted `ChatView.swift:54-57`. Auto-approve via `DataStore.shouldAutoApprove` (`DataStore.swift:304-318`). |
| 10 | Drag-drop attachments + PDF/image preview | 🟡 | Drop wired `ChatInputBarView.swift:71-77`; preview sheet uses real PDFKit + AsyncImage (`ChatAttachmentPreviewSheet.swift:45-62`). PARTIAL: in `send()`, images/PDFs are inlined only as a path string with an explicit `TODO` for image blocks (`ChatViewModel.swift:241-248`); only text/code is actually fed to the model. |
| 11 | Live token counter | ✅ | Parsed from SDK `result.usage` (`StreamEvent.swift:232-239`, `decodeUsage`); accumulated `ChatViewModel.swift:466-477`; rendered `ChatView.swift:tokenChips:157-171`. |
| 12 | Regenerate-last-turn | ✅ | `ChatViewModel.swift:318-350` walks back to last user turn, respawns, re-sends; wired from `ChatView.swift:292`. |
| 13 | Multi-tab chats | ✅ | `Views/Chats/ChatTabContainerView.swift` full tab strip, add/close/select, per-tab `ChatView` via `.id()`; mounted `ChatsView.swift:30`. |
| 14 | In-app docs tab | ✅ | `Services/DocsLoader.swift:7-43` loads/searches 15 bundled `.md` files in `Resources/Docs`; `ViewModels/DocsViewModel.swift`; `Views/Docs/*` mounted `ContentView.swift:25`. |
| 15 | Menu-bar NSStatusItem | ✅ | `Views/MenuBar/StatusItemController.swift:68-79` creates a real `NSStatusBar.system.statusItem`, builds NSMenu with recents submenu; installed in `AppDelegate.swift:29`. |
| 16 | SwiftData persistence (6 @Model entities) | ✅ | `Persistence/DataStore.swift:12-19` schema with all 6 entities (SessionMeta, SessionStats, Favorite, Tag, ChatTranscript, PermissionDecision); persistent (`isStoredInMemoryOnly: false`). |
| 17 | Telemetry / CrashReporter | 🟡 | Telemetry (`Services/Telemetry.swift:29-36`): opt-in gated, but "No backend yet — just log to stderr". CrashReporter (`Services/CrashReporter.swift:9-13,28-39`): genuinely registers as `MXMetricManagerSubscriber`, but payloads are only printed and `recentDiagnostics()` returns `[]`. Both wired from `AppDelegate.swift:30-31`. Real plumbing, no sink. |

## Build & test sanity

Tooling present: `xcodegen 2.45.3`, `xcodebuild` (Xcode **26.3**, build 17C529 — note:
newer than the "Xcode 16" the task stated, but it builds cleanly), `node` + `npm`
at `/opt/homebrew/bin`.

Commands run from `swift/`:

```
xcodegen generate                       # OK — wrote Claude-MTW-Replay.xcodeproj
xcodebuild ... build CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/cr-build
```

- **Build result: `** BUILD SUCCEEDED **`** — 0 `error:` lines, 406 `warning:` lines.
- The `Copy sidecar bundle` post-build script (`project.yml:34-44`) ran; the built
  `.app/Contents/Resources/Sidecar/` contains `sidecar.js`, `package.json`, and
  `node_modules` (including `@anthropic-ai/claude-agent-sdk`). Verified by `ls`.

```
xcodebuild ... test CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/cr-build
```

- **Test result: `** TEST SUCCEEDED **`** — **109 tests executed, 0 failures, 3
  skipped.** The 3 skips are WebKit-dependent `HTMLRendererTests` (skipped by
  design). Notably `ClaudeAgentSkeletonTests.testEchoRoundTrip` **ran and passed**
  (1 test, 0 failures) — it spawned the real `node sidecar.js --skeleton` and
  round-tripped two echo messages, proving the stdio plumbing works on a host with
  node installed.

### Sidecar build note (not run)
`sidecar/build.sh` runs `npm install --omit=dev` then copies into the app's
`Sidecar/` folder. Per the user's standing instruction not to run `npm` locally,
this was **not executed**. It does not need to be: `node_modules` (with the SDK) is
already present and was copied into the built app. `build.sh` would only be needed
to refresh/clean-install deps.

## Fragile / half-built

- **Attachments (image/PDF) — half-built (🟡).** Text/code attachments are fully
  inlined into the prompt; image/PDF/other are passed only as a `[image attachment:
  <path>]` string with an explicit `TODO` (`ChatViewModel.swift:241-248`). Claude
  can only see them if it independently `Read`s the path. Preview UI is complete.
- **Telemetry / CrashReporter — no sink (🟡).** Plumbing is real (opt-in flag,
  MetricKit subscriber registered) but there is no backend; events/payloads only
  print to stderr and `recentDiagnostics()` is hard-coded `[]`.
- **System-prompt CLAUDE.md/MEMORY.md toggles — inert.** The two checkboxes in
  `SystemPromptSheet` set VM fields that are explicitly documented as "reserved for
  the sidecar" and do not affect the request today. The system-prompt *text* itself
  is fully wired.
- **Slash command `$ARGUMENTS` — always empty.** Commands expand, but trailing
  args from `/cmd foo bar` are not piped (`ChatInputBarView.swift:298`).
- **TextEditor Enter-vs-Shift+Enter** (`ChatInputBarView.swift:272-279`): plain
  Enter inserts a newline; send is via the button / Cmd+Enter. A known UX
  compromise, noted in-code, not a defect.
- **Model ids are unvalidated** (`ChatModelPickerView.swift:23-27`): forwarded
  verbatim to the SDK; if the SDK renames a model the picker silently breaks.

## Conclusion

The Swift app's claimed extras are substantially genuine. 14/17 are fully wired
end-to-end with no stubs or disabled paths; the 3 partials are honestly-scoped and
documented in-code (telemetry/crash sinks, binary attachments). The flagship
sidecar chat path is real and exercised by a passing integration test. The project
builds and all 109 tests pass.
