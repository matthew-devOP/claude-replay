# FAQ

> Common questions, with pointers to the relevant docs.

## Why won't chats work?

The Chats tab depends on a Node 20+ runtime and the bundled sidecar. Open **Settings → Sidecar** and check the status of `node` and `claude`. If either is red, hit **Locate…** and pick the binary. Login-shell-managed runtimes (`asdf`, `fnm`, `volta`) work — the locator runs `zsh -lc 'command -v node'` to find them. See [Settings → Sidecar](settings.md#sidecar).

## Sessions don't appear in the sidebar

Three things to check:

1. `~/.claude/projects/` (or `~/.claude-<name>/projects/`) actually exists and has at least one session JSONL. The app does not create the directory for you.
2. The **Account** dropdown is set to the right Claude install. If it shows `(yahoo)` but you ran Claude under default, switch back. See [Accounts](accounts.md).
3. Click **Refresh** in the sidebar header. The watcher catches most changes automatically but a freshly created directory may need a manual rescan.

## Are secrets in my transcripts safe to share?

By default every export is run through `SecretRedactor` with 11 built-in patterns: private keys, AWS keys, Anthropic `sk-ant-*` keys, generic `sk_*` / `pk_*` keys, bearer tokens, JWTs, database connection strings, `key=value` pairs in environment lines, hex-encoded tokens, and a few others. Redaction is recursive — tool input dictionaries and Bash commands are scrubbed too. Toggle it off via [Settings → Security](settings.md#security) if you want a faithful export, but understand the implications. We do not currently let you redact individual rules; it is all or nothing.

## My custom theme isn't loading

Open the JSON in a text editor and check:

1. The file parses (no trailing commas, balanced braces).
2. `name` is a string and not already used by a built-in theme — or you want the override on purpose.
3. `parent` (optional) matches one of the built-in theme names: `claude-dark`, `claude-light`, `tokyo-night`, `monokai`, `solarized-dark`, `github-light`, `dracula`, `bubbles`.
4. Hex colors are six-digit or eight-digit (alpha). Three-digit short form (`#abc`) is also accepted.

After fixing, hit **Settings → Custom Themes → Reload from disk**. See [Settings → Custom Themes](settings.md#custom-themes).

## My chat cost is $0.0000

Cost is reported by the SDK only at the end of a turn via the `result.total_cost_usd` event. Until the first complete response lands, the chip stays at zero. Some models (like the default `claude-default`) do not emit usage information at all in certain environments; switch to an explicit model in the [Chats model picker](chats.md#model-picker) to see real numbers.

## The permission popup keeps appearing for the same tool

When the modal pops up, click **Always**. The decision is persisted per `(sessionId, toolName, action_signature)`. If you still see prompts, the action signature is changing — e.g. a Bash call with a different command. Switch the **Mode** to **Accept Edits** to auto-approve everything for the rest of the session.

## How do I fork a conversation?

In the [Chats](chats.md) transcript, right-click any user turn and choose **Branch from here**. The app duplicates the underlying JSONL, truncates it at that turn, and opens a new chat tab against the branch. The parent relationship is recorded in SwiftData; in the future this will surface as a tree.

## Can I edit a sent message?

Not directly — the SDK does not support editing past turns. Fork the conversation at the user turn you want to change, then send a new message from the branch.

## My MCP server isn't showing up

Open **Settings → MCP servers** and confirm the spec is complete (name, command, args). After saving, restart any active chat (or use the **Reload** button in the Chats header) so the SDK re-imports `options.mcpServers`. If the server fails to start the sidecar logs it on stderr; check the **Show sidecar logs** option in Settings to see what went wrong.

## What's the difference between Plan, Accept Edits, and Default mode?

- **Plan** — the agent can read and think but cannot execute mutating tools. Best for "what would you do?" questions.
- **Accept Edits** — every tool call is auto-approved. Use when you trust the project.
- **Default** — every mutating tool call triggers a permission prompt (Once / Always / Never). Safe default for new projects.

There is also `bypassPermissions` (`--allowDangerouslySkipPermissions`), but it is intentionally hidden from the UI to prevent accidental enables.

## Can I run multiple chats at once?

Yes. The Chats tab has an internal tab strip with a `+` to open new chats and a close affordance per tab. Each tab has its own `ChatViewModel` and sidecar, so a stuck one will not block the others. See [Chats → Multi-tab](chats.md#multi-tab).

## How do I share a replay with someone who doesn't have the app?

Export to **HTML**. The result is a single, self-contained file with the player template, theme CSS, and your turns inlined. They double-click it; their browser does the rest. See [Export](export.md).

Related: [Troubleshooting](troubleshooting.md) · [Settings](settings.md).
