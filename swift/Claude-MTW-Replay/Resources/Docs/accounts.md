# Accounts (multi-account)

> Run Claude Code under several identities on one Mac and switch between them in one click.

## What counts as an account?

Claude Code stores its state under `~/.claude` by default. To use a different identity you point the CLI at a different config directory via the `CLAUDE_CONFIG_DIR` environment variable. Claude MTW Replay picks up **any** directory in your home folder named `.claude-*` (or `.claude_*`) that contains a `projects/` subdirectory, and treats it as a separate account.

Typical layout:

```
~/.claude            -> "main"
~/.claude-yahoo      -> "yahoo"
~/.claude-outlook    -> "outlook"
~/.claude-work       -> "work"
```

The label is derived by stripping the `.claude-` prefix.

## How auto-discovery works

`AccountStore.availableAccounts()` scans your home directory on demand (called from the AccountSwitcherMenu when it appears) and returns every match. The result feeds the toolbar dropdown and the sidebar header switcher.

The default account `~/.claude` is always present and always sits first. If only the default exists, no switcher is shown — the UI hides single-account complexity.

## Switching accounts

Open the **Account** dropdown in the top toolbar (or the sidebar header) and pick the one you want. Internally:

1. `appState.setClaudeAccount(_:)` writes the chosen directory to `UserDefaults` (`claudeAccountDir`).
2. Sidebar `.task(id: claudeAccountDir)` re-runs and calls `SessionDiscovery.discoverProjects(claudeAccountDir:)`.
3. The Claude Code session group is relabelled — for example, `Claude Code (yahoo)` instead of just `Claude Code`.

The current selection persists between launches.

## What changes per account

Account isolation is enforced at three layers:

- **Listing.** The Dashboard, Replay, Editor, Stats, and Git tabs only see projects under the current account root. Cursor and Codex CLI sessions remain visible regardless (their state lives in `~/.cursor/projects/` and `~/.codex/sessions/`).
- **Chat history.** Each account has its own SDK transcript files and credentials. Claude pricing, MCP servers, and CLAUDE.md global memory are all per-account.
- **Live chat sidecar.** When you start a Chat the app sets `CLAUDE_CONFIG_DIR` on the spawned Node process to the active account directory, so the agent SDK reads the right credentials and writes back to the right `projects/` folder.

## Setting up a second account

The CLI side of the work is done outside of this app:

```bash
# Create the directory shell
mkdir -p ~/.claude-yahoo

# Run claude once with that config dir to log in as the second identity
CLAUDE_CONFIG_DIR=~/.claude-yahoo claude
```

Once you have started a real session under the new directory, restart Claude MTW Replay (or hit Refresh on the sidebar) and the new account appears in the dropdown.

## Notes and edge cases

- We do not parse `~/.claude/config.json` or call out to `claude` to enumerate accounts — discovery is purely filesystem-based.
- Renaming a directory after the app started will need a Refresh.
- The app never writes inside an account directory other than what the SDK does on your behalf during live chat.
- See the Docker volume strategy used by the web CLI (commit `54e566e`) for a sample multi-account topology — it mirrors what the native app expects on disk.

Related: [Getting started](getting-started.md) · [Chats](chats.md) · [Settings](settings.md).
