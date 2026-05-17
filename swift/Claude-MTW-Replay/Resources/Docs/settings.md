# Settings

> Everything that lives behind Cmd+, — playback defaults, security, display, themes, telemetry, MCP servers, and the sidecar locator.

Settings is a standard macOS Preferences window. Changes apply instantly and persist to `UserDefaults` unless noted otherwise.

## Playback

- **Default speed** — initial value for the Replay speed picker (`0.5x` … `20x`). Persisted as `defaultSpeed`.
- **Show thinking by default** — toggle, persisted as `showThinkingByDefault`.
- **Show tool calls by default** — toggle, persisted as `showToolCallsByDefault`.

## Security

- **Auto-redact secrets** — when enabled (default), every export passes through `SecretRedactor.redactObject(_:)` which recursively scrubs 11 built-in patterns (private keys, AWS keys, Anthropic API keys, generic `sk_*` keys, bearer tokens, JWTs, connection strings, generic `key=value`, env-vars, hex tokens). Persisted as `autoRedactSecrets`.

There is no per-rule UI; all 11 patterns apply together. To audit which patterns matched, set `autoRedactSecrets` off temporarily and diff the export.

## Display

- **Tool grouping threshold** — minimum consecutive `tool_use` blocks before they collapse into a single disclosure (default `5`). Setting this to `1` reproduces the web app's behavior of grouping every consecutive run.
- **Default OG image URL** — used as the `og:image` for HTML exports unless overridden in the Export sheet.
- **Embed JSON uncompressed** — when on, HTML exports skip the zlib + base64 step. Useful for debugging.

## Custom themes

A list of registered custom themes plus two buttons:

- **Import…** opens an `NSOpenPanel` filtered to `.json`. The file is parsed by `ThemeService.loadThemeFile(_:)` and the theme name is derived from the filename (without the extension). Imported paths are stored in `UserDefaults`; the JSON itself stays on disk so you can edit it externally.
- **Reload from disk** re-reads every registered theme file. Use this after editing a theme JSON in your editor.

### Custom theme JSON format

```json
{
  "name": "midnight-blue",
  "parent": "claude-dark",
  "colors": {
    "bg": "#0a0e1f",
    "bgSurface": "#101426",
    "bgHover": "#1a1f3a",
    "text": "#e6e9f5",
    "textDim": "#8a93b5",
    "textBright": "#ffffff",
    "accent": "#5b9eff",
    "accentDim": "#3672cc",
    "green": "#5fd478",
    "blue": "#5b9eff",
    "orange": "#ffb454",
    "red": "#ff5d6b",
    "cyan": "#5fdde5",
    "border": "#2a2f4a",
    "toolBg": "#141a30",
    "thinkingBg": "#0e1326"
  },
  "extraCss": ":root { --code-radius: 8px; }"
}
```

- `name` is required and must be unique among loaded themes. Conflicts override the built-in of the same name.
- `parent` is optional. When set, missing colors are inherited from the parent theme. Use `claude-dark`, `claude-light`, `tokyo-night`, etc.
- `colors` keys are the same set used by built-in themes; anything missing falls back to the parent (or to `claudeDark` if no parent is set).
- `extraCss` is appended verbatim to HTML exports only.

Once loaded, a custom theme appears in the Theme menu and in the Export sheet alongside the built-ins.

## Privacy & Diagnostics

- **Send anonymous usage stats** — off by default. When enabled, MetricKit data and a small set of high-level events (`app_launched`, `tab_switched`, `chat_started`, `export_clicked`) are sent. No transcript content ever leaves your machine.
- **MetricKit status** — last successful submission timestamp.
- **Privacy policy** button — opens the policy URL in your default browser.
- **Open crash reports folder** — reveals the local MetricKit / sentry buffer in Finder.

## MCP servers

A list of Model Context Protocol server definitions. Each entry stores:

- `name` — slug used in slash commands.
- `command` — executable path, e.g. `npx`.
- `args` — array of arguments.
- `env` — optional environment overrides as key/value pairs.

Definitions are persisted in `UserDefaults` and forwarded to `sidecar.js` as `options.mcpServers`. When you add a server, restart any active chat (or use the **Reload** button in the Chats header) so the SDK picks up the new tool definitions. See [Chats → MCP badge](chats.md#mcp-badge) for the in-conversation surface.

## Sidecar

Two file pickers backing `SidecarLocator`:

- **Path to node** — defaults to whatever was discovered in `/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin`, or the login shell. Override via **Locate…** (filtered to executables); persisted as `sidecarLocator.node`.
- **Path to claude** — defaults to the same plus `~/.local/bin/claude` and `~/.claude/local/claude`. Override via **Locate…**; persisted as `sidecarLocator.claude`.

Each row shows a status indicator: green if the binary is found and executable, red if the path is missing or non-executable. After a change, restart Chats sessions to pick up the new path.

Related: [Chats](chats.md) · [Export](export.md) · [Troubleshooting](troubleshooting.md).
