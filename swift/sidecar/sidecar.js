#!/usr/bin/env node
/**
 * claude-mtw-replay sidecar — bridges the Swift Chats UI to the Claude Agent
 * SDK (or to a simple echo loop while the Swift wrapper is being built).
 *
 * Wire format
 *   stdin   : line-delimited JSON commands.
 *               { "type": "send",  "text": "<user message>" }
 *               { "type": "stop" }                  // graceful shutdown
 *   stdout  : line-delimited JSON events.
 *               { "type": "ready" }
 *               { "type": "echo",  "input": "..." }   // skeleton mode
 *               { "type": "agent_event", "event": <SDK event> }   // real mode
 *               { "type": "error", "message": "..." }
 *               { "type": "exit",  "code": 0 }
 *
 * Argv
 *   --resume <sessionId>           Resume a Claude Code session by id (required for real mode)
 *   --cwd <projectPath>            Working directory for the agent
 *   --permission-mode <mode>       acceptEdits | auto | bypassPermissions | default | dontAsk | plan
 *   --allowed-tools <list>         Comma-separated tool names
 *   --partial-messages             Pass `includePartialMessages: true` (verbose)
 *   --skeleton                     Skip the SDK and just echo (used until step 5 lands)
 *
 * The skeleton mode is what step 1 of the v0.8.0-swift plan ships. Step 5
 * replaces the body of `runAgent()` with a real call to
 * `query()` from `@anthropic-ai/claude-agent-sdk`.
 */

import { createInterface } from "node:readline";
import { stdin, stdout, stderr, argv, exit } from "node:process";

// ─── Argv ───────────────────────────────────────────────────────────────

function parseArgs(rawArgs) {
  const args = { skeleton: false, partialMessages: false };
  for (let i = 0; i < rawArgs.length; i++) {
    const a = rawArgs[i];
    if (a === "--skeleton")          args.skeleton = true;
    else if (a === "--partial-messages") args.partialMessages = true;
    else if (a === "--resume")        args.resume = rawArgs[++i];
    else if (a === "--cwd")           args.cwd = rawArgs[++i];
    else if (a === "--permission-mode") args.permissionMode = rawArgs[++i];
    else if (a === "--allowed-tools") args.allowedTools = rawArgs[++i];
  }
  return args;
}

const args = parseArgs(argv.slice(2));

// ─── stdout helpers ─────────────────────────────────────────────────────

function emit(obj) {
  stdout.write(JSON.stringify(obj) + "\n");
}

function fatal(message, code = 1) {
  emit({ type: "error", message });
  emit({ type: "exit", code });
  exit(code);
}

// ─── Skeleton mode ──────────────────────────────────────────────────────
// Emits one echo event per stdin line. Lets the Swift wrapper be developed
// and tested before the SDK integration lands.

async function runSkeleton() {
  emit({ type: "ready", mode: "skeleton" });
  const rl = createInterface({ input: stdin, crlfDelay: Infinity });
  for await (const line of rl) {
    if (!line.trim()) continue;
    let cmd;
    try { cmd = JSON.parse(line); }
    catch { emit({ type: "error", message: "invalid JSON on stdin: " + line }); continue; }
    if (cmd?.type === "stop") break;
    if (cmd?.type === "send") emit({ type: "echo", input: cmd.text ?? "" });
    else emit({ type: "error", message: "unknown command type: " + (cmd?.type ?? "<missing>") });
  }
  emit({ type: "exit", code: 0 });
}

// ─── Real agent mode (filled in by step 5) ──────────────────────────────

async function runAgent() {
  // TODO(step 5): replace with @anthropic-ai/claude-agent-sdk's query() and
  // forward each yielded SDK event as { type: "agent_event", event } on stdout.
  fatal("agent mode not yet implemented (run with --skeleton until step 5)", 2);
}

// ─── Entry ──────────────────────────────────────────────────────────────

(async () => {
  try {
    if (args.skeleton) await runSkeleton();
    else                await runAgent();
  } catch (err) {
    fatal(err?.stack ?? String(err), 1);
  }
})();
