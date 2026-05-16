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

// ─── Protocol versioning + hello handshake ──────────────────────────────
// Emit a `hello` frame first thing so the Swift host can validate the
// wire-protocol version before sending any commands. Keep this BEFORE
// any other I/O so receivers always see it as line #1.

const PROTOCOL_VERSION = "1";
const SIDECAR_VERSION = "0.8.1";

function send(obj) {
  stdout.write(JSON.stringify(obj) + "\n");
}

send({ type: "hello", protocol: PROTOCOL_VERSION, version: SIDECAR_VERSION, pid: process.pid });

// ─── Structured logging ─────────────────────────────────────────────────
// Routes all diagnostic output through the stdout JSONL channel so the
// Swift wrapper can surface it as typed log events. Levels: debug | info
// | warn | error.

function log(level, msg, meta = null) {
  const entry = { type: "log", level, msg };
  if (meta) entry.meta = meta;
  send(entry);
}

// ─── Heartbeat ──────────────────────────────────────────────────────────
// Periodic liveness ping so the Swift watchdog can detect a zombied
// sidecar (event loop alive but stuck). `unref()` so the timer never
// keeps the process alive on its own.

const HEARTBEAT_MS = 30_000;
const heartbeatTimer = setInterval(() => {
  send({ type: "heartbeat", ts: Date.now() });
}, HEARTBEAT_MS);
heartbeatTimer.unref();

function stopHeartbeat() {
  clearInterval(heartbeatTimer);
}

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
    else if (a === "--disallowed-tools") args.disallowedTools = rawArgs[++i];
    else if (a === "--model")         args.model = rawArgs[++i];
    else if (a === "--custom-system-prompt") args.customSystemPrompt = rawArgs[++i];
  }
  return args;
}

const args = parseArgs(argv.slice(2));

// ─── stdout helpers ─────────────────────────────────────────────────────
// `emit` is a thin alias over `send` (declared above so `hello` can fire
// before parseArgs). Keeping the name so the rest of the file reads the
// same as it did before the versioning rework.

function emit(obj) {
  send(obj);
}

function fatal(message, code = 1) {
  log("error", message);
  emit({ type: "error", message });
  emit({ type: "exit", code });
  stopHeartbeat();
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
  stopHeartbeat();
}

// ─── Real agent mode ────────────────────────────────────────────────────
//
// Bridges the SDK's `query()` to our line-protocol stdio:
//   - We open an async generator that yields one `SDKUserMessage` per
//     `{type:"send",text}` line on stdin. The generator stays open until
//     a `{type:"stop"}` line or EOF arrives, which is what keeps the
//     SDK's session loaded in memory across multiple turns (no per-message
//     JSONL replay tax).
//   - We for-await the `Query` (which is an AsyncGenerator<SDKMessage>)
//     and forward every event to stdout as `{type:"agent_event",event}`.
//   - On any throw, we emit a structured error and exit cleanly so the
//     Swift wrapper can surface it.

async function runAgent() {
  if (!args.resume) fatal("missing required --resume <sessionId>", 2);

  // Lazy require so --skeleton mode doesn't pay the SDK load cost.
  const { query } = await import("@anthropic-ai/claude-agent-sdk");

  // Track the live session id. It might be replaced by the SDK on
  // first message (if --resume is normalised). We seed with the user's
  // requested resume id so the first yielded user message carries it.
  let sessionId = args.resume;

  // ── Stdin pump → user message generator ────────────────────────────
  const stdinLines = createInterface({ input: stdin, crlfDelay: Infinity });
  const pendingMessages = [];
  let stdinClosed = false;
  let resolveNext = null;

  // Drain stdin in the background, parse each line, queue user messages,
  // and signal `userMessages()` to advance.
  (async () => {
    for await (const raw of stdinLines) {
      if (!raw.trim()) continue;
      let cmd;
      try { cmd = JSON.parse(raw); }
      catch { emit({ type: "error", message: "invalid JSON on stdin: " + raw }); continue; }
      if (cmd?.type === "stop") { stdinClosed = true; resolveNext?.(); break; }
      if (cmd?.type === "send" && typeof cmd.text === "string") {
        pendingMessages.push(cmd.text);
        resolveNext?.();
      } else {
        emit({ type: "error", message: "unknown command type: " + (cmd?.type ?? "<missing>") });
      }
    }
    stdinClosed = true;
    resolveNext?.();
  })().catch((err) => {
    log("error", "stdin pump failed", { stack: err?.stack ?? String(err) });
    emit({ type: "error", message: "stdin pump: " + (err?.stack ?? err) });
  });

  async function* userMessages() {
    while (true) {
      // Drain whatever's queued.
      while (pendingMessages.length > 0) {
        const text = pendingMessages.shift();
        yield {
          type: "user",
          message: { role: "user", content: text },
          parent_tool_use_id: null,
          session_id: sessionId,
        };
      }
      if (stdinClosed) return;
      // Park until either a new message arrives or stdin closes.
      await new Promise((resolve) => { resolveNext = resolve; });
      resolveNext = null;
    }
  }

  // ── Build the SDK Options block from argv ──────────────────────────
  const options = {
    resume: args.resume,
    cwd: args.cwd,
    permissionMode: args.permissionMode || "default",
    includePartialMessages: !!args.partialMessages,
  };
  // G6 — explicit allow/deny lists. We always set `allowedTools` when the
  // flag was passed (even with an empty array, which sandboxes the agent
  // to zero tools — distinct from `undefined`, which means SDK default).
  if (typeof args.allowedTools === "string") {
    options.allowedTools = args.allowedTools.split(",").map((s) => s.trim()).filter(Boolean);
  }
  if (typeof args.disallowedTools === "string") {
    options.disallowedTools = args.disallowedTools.split(",").map((s) => s.trim()).filter(Boolean);
  }
  // G4 — forward the explicit model id when the picker selected a
  // non-default. The SDK falls back to its current default model when
  // this is unset.
  if (args.model) {
    options.model = args.model;
  }
  // G5 — appended to the SDK's default system prompt (the SDK accepts
  // either a plain string or a {type:"preset",preset:"claude_code",append}
  // object). Sending a string is the simplest contract for our use case.
  if (args.customSystemPrompt) {
    options.customSystemPrompt = args.customSystemPrompt;
  }
  if (options.permissionMode === "bypassPermissions") {
    // SDK requires explicit opt-in for bypass — match that here so the
    // Swift toggle "just works" when picked.
    options.allowDangerouslySkipPermissions = true;
  }

  // ── Run the query and forward events ───────────────────────────────
  emit({ type: "ready", mode: "agent", resume: args.resume, permissionMode: options.permissionMode });

  let q;
  try {
    q = query({ prompt: userMessages(), options });
  } catch (err) {
    fatal("query() threw synchronously: " + (err?.stack ?? err), 1);
  }

  try {
    for await (const event of q) {
      // Track the active session id so subsequent user messages carry it.
      if (event && typeof event === "object" && typeof event.session_id === "string") {
        sessionId = event.session_id;
      }
      emit({ type: "agent_event", event });
    }
    emit({ type: "exit", code: 0 });
    stopHeartbeat();
  } catch (err) {
    // SDK's AbortError is expected when we interrupt a turn from Swift.
    if (err?.name === "AbortError") {
      emit({ type: "exit", code: 0 });
      stopHeartbeat();
    } else {
      log("error", "agent loop failed", { stack: err?.stack ?? String(err) });
      emit({ type: "error", message: err?.stack ?? String(err) });
      emit({ type: "exit", code: 1 });
      stopHeartbeat();
      exit(1);
    }
  }
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
