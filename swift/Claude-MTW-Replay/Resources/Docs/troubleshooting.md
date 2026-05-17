# Troubleshooting

> When something is misbehaving, start here.

## Chat will not start

Symptom: clicking **Resume** spins on `Connecting…` then drops to **Error**.

Checklist:

1. Open **Settings → Sidecar**. Both `node` and `claude` should be green. If not, click **Locate…** and pick the binary. The locator falls back to `zsh -lc 'command -v node'`, so version managers (`asdf`, `fnm`, `volta`) are usually found automatically — but only if your login shell sources them.
2. Confirm Node is at least version 20. From a terminal: `node --version`. The sidecar uses `await import(...)` and refuses to run on older Node.
3. Check that `Bundle.main.resourceURL/Sidecar/sidecar.js` exists. Right-click the app in Finder → **Show Package Contents** → `Contents/Resources/Sidecar/sidecar.js`. If missing, the DMG is incomplete; reinstall.

See [Chats](chats.md) for the full architecture.

## Chat hangs mid-response

A heartbeat watchdog kills the sidecar after **90 seconds** of silence. When that fires you will see an error chip with the last log line. To investigate:

1. Toggle **Settings → Show sidecar logs** to surface stderr in real time.
2. Look in `Console.app` filtered by `Claude-MTW-Replay` — the parent process logs the spawn arguments and exit code.
3. If the SDK itself hung (long tool call), pressing `Esc` issues a graceful stop, waits 1 s, then terminates. Sometimes Bash subprocesses survive — kill them by hand if needed.

## HTML export fails

Most failures fall into two buckets:

- **Template missing.** The `Resources/player.min.html` (or `player.html` fallback) file is part of the bundle. If the export panel reports "template not found", the bundle is damaged — reinstall.
- **Invalid theme name.** When you reference a deleted custom theme by name the renderer raises. Switch to a built-in theme in the Export sheet and try again. See [Settings → Custom Themes](settings.md#custom-themes).

PDF export goes through `WKWebView`. Very long replays (~thousands of turns) can take several seconds and may briefly look like a hang — wait for `ExportProgressView` to finish.

## Sessions are stale

If the Dashboard table looks out of date:

- Hit **Refresh** on the sidebar header.
- Check the **Account** dropdown — switching accounts triggers a full rescan.
- Confirm the `FileWatcher` has not been quarantined. macOS sometimes detaches the file descriptor when the system sleeps; quitting and relaunching the app fixes it.

## Custom theme failed to load

The JSON parser will silently skip malformed files. To see the actual error:

1. Open **Settings → Custom Themes → Reload from disk**.
2. The status row next to each theme shows the result. Bad files surface a red warning with a tooltip containing the parse error.
3. Fix the file in your editor and reload again. See the schema in [Settings → Custom Themes](settings.md#custom-themes).

## Build issues (when building from source)

Requires:

- Xcode 16+ (Swift 5.9 toolchain).
- macOS 15 SDK.
- `xcodegen` (regenerate `.xcodeproj` from `project.yml`).
- `node 20+` and `npm` (for the sidecar `build.sh`).

If the build complains about strict concurrency, double-check that you have not introduced an unannotated `class`; the project sets `SWIFT_STRICT_CONCURRENCY = complete`.

## Crash reports

MetricKit collects crashes locally and ships them to the configured backend only when **Settings → Privacy & Diagnostics → Send anonymous usage stats** is on. To see the local cache:

1. Open **Settings → Privacy & Diagnostics**.
2. Click **Open crash reports folder** — Finder reveals the buffered payloads.
3. Drop them into a bug report (after redacting your `~` username from any stack frames).

## Sidecar protocol mismatch

The sidecar sends a `hello` line as its first message: `{"type":"hello","protocol":"1"}`. The app validates this. If the protocol number does not match, the app refuses to connect and surfaces:

> Sidecar protocol mismatch (expected 1, got X)

This usually means the bundled sidecar is from a newer build and the Swift binary is from an older one (or vice versa). Reinstall a matching DMG.

## Multi-account confusion

Two common gotchas:

- **Costs look wrong.** Each account has its own credentials and pricing tier. Make sure the **Account** dropdown matches the account you actually billed.
- **CLAUDE.md is empty.** The CLAUDE.md panel reads from the project directory, which is the same regardless of account. If a file is missing it really is missing.

See [Accounts](accounts.md).

## Performance is sluggish

- The lazy enrichment cache builds up in SwiftData. Quitting and relaunching is harmless.
- Long sessions (~10 000 turns) make the Replay autoscroll choppy on Intel Macs. Lower **Speed** to 1x and toggle off thinking blocks to reduce per-frame work.
- The activity heatmap recomputes when you switch projects; if a project has hundreds of thousands of events, the recompute takes a couple of seconds.

Related: [FAQ](faq.md) · [Settings](settings.md) · [Chats](chats.md).
