/**
 * Local HTTP server for the web-based replay editor.
 */

import { createServer } from "node:http";
import { readFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { resolve, join, dirname, basename } from "node:path";
import { homedir } from "node:os";
import { execFile } from "node:child_process";
import { parseTranscript, filterTurns, detectFormat, applyPacedTiming } from "./parser.mjs";
import { render } from "./renderer.mjs";
import { getTheme, listThemes, getAllThemes } from "./themes.mjs";

const EDITOR_HTML_PATH = new URL("../template/editor.html", import.meta.url);
const PKG = JSON.parse(readFileSync(new URL("../package.json", import.meta.url), "utf-8"));

// ---------------------------------------------------------------------------
// In-memory session store
// Map<sessionId, { originalTurns, workingTurns, sourcePath, format }>
// ---------------------------------------------------------------------------

const sessions = new Map();
let sessionCounter = 0;

// ---------------------------------------------------------------------------
// HTTP helpers
// ---------------------------------------------------------------------------

const MAX_BODY_SIZE = 10 * 1024 * 1024; // 10 MB

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    let settled = false;
    req.on("data", (c) => {
      if (settled) return;
      size += c.length;
      if (size > MAX_BODY_SIZE) {
        settled = true;
        req.destroy();
        reject(new Error("Request body too large"));
        return;
      }
      chunks.push(c);
    });
    req.on("end", () => {
      if (settled) return;
      settled = true;
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString()));
      } catch {
        reject(new Error("Invalid JSON body"));
      }
    });
    req.on("error", (err) => {
      if (settled) return;
      settled = true;
      reject(err);
    });
  });
}

function json(res, data, status = 200) {
  const body = JSON.stringify(data);
  res.writeHead(status, {
    "Content-Type": "application/json",
    "Content-Length": Buffer.byteLength(body),
  });
  res.end(body);
}

function error(res, message, status = 400) {
  json(res, { error: message }, status);
}

// ---------------------------------------------------------------------------
// Session helpers
// ---------------------------------------------------------------------------

/** Summarize a turn's blocks into a human-readable string. */
function summarizeBlocks(blocks) {
  const counts = { text: 0, thinking: 0, tool_use: 0 };
  for (const b of blocks) {
    counts[b.kind] = (counts[b.kind] || 0) + 1;
  }
  const parts = [];
  if (counts.text) parts.push(`${counts.text} text`);
  if (counts.thinking) parts.push(`${counts.thinking} thinking`);
  if (counts.tool_use) parts.push(`${counts.tool_use} tool call${counts.tool_use > 1 ? "s" : ""}`);
  return parts.join(", ") || "empty";
}

/** Map a block to a lightweight shape for the client. */
function summarizeBlock(b) {
  if (b.kind === "tool_use" && b.tool_call) {
    return {
      kind: b.kind,
      name: b.tool_call.name,
      input: truncate(JSON.stringify(b.tool_call.input), 200),
      result: truncate(b.tool_call.result || "", 500),
    };
  }
  return { kind: b.kind, text: truncate(b.text || "", 1000) };
}

function truncate(s, max) {
  return s.length > max ? s.slice(0, max) + "…" : s;
}

/** Map full turns to the lightweight shape sent to the client. */
function summarizeTurns(turns) {
  return turns.map((t) => ({
    index: t.index,
    user_text: t.user_text,
    blockSummary: summarizeBlocks(t.blocks),
    blocks: t.blocks.map(summarizeBlock),
    timestamp: t.timestamp,
    system_events: t.system_events || [],
  }));
}

/** Resolve a theme name, falling back to tokyo-night. */
function getThemeSafe(name) {
  try {
    return getTheme(name);
  } catch {
    return getTheme("tokyo-night");
  }
}

/**
 * Prepare turns for rendering: clone, filter, re-index, apply timing.
 * Returns ready-to-render turns array.
 */
function prepareTurns(session, options) {
  let turns = session.workingTurns;
  if (options.excludeTurns && options.excludeTurns.length > 0) {
    turns = filterTurns(turns, { excludeTurns: options.excludeTurns });
  }
  const cloned = JSON.parse(JSON.stringify(turns));
  // Re-index sequentially so the player's position-based logic matches turn.index
  for (let i = 0; i < cloned.length; i++) {
    cloned[i].index = i + 1;
  }
  const timing = options.timing || "auto";
  const hasTimestamps = cloned.some((t) => t.timestamp);
  if (timing === "paced" || (timing === "auto" && !hasTimestamps)) {
    applyPacedTiming(cloned);
  }
  return cloned;
}

/**
 * Remap bookmark turn indices from original to new sequential indices.
 * Bookmarks pointing to excluded turns are dropped.
 */
function remapBookmarks(bookmarks, originalTurns, excludedSet) {
  if (!bookmarks || bookmarks.length === 0) return [];
  // Build mapping: original index → new sequential index
  const indexMap = new Map();
  let seq = 1;
  for (const t of originalTurns) {
    if (!excludedSet.has(t.index)) {
      indexMap.set(t.index, seq++);
    }
  }
  return bookmarks
    .map((bm) => ({ turn: indexMap.get(bm.turn), label: bm.label }))
    .filter((bm) => bm.turn != null)
    .sort((a, b) => a.turn - b.turn);
}

/** Build render options from client options + session metadata. */
function buildRenderOpts(options, session, overrides = {}) {
  const excludedSet = new Set(options.excludeTurns || []);
  return {
    speed: parseFloat(options.speed) || 1.0,
    showThinking: options.showThinking !== false,
    showToolCalls: options.showToolCalls !== false,
    theme: getThemeSafe(options.theme || "tokyo-night"),
    redactSecrets: options.redactSecrets !== false,
    redactRules: options.redactRules || [],
    userLabel: options.userLabel || "User",
    assistantLabel: options.assistantLabel || (session.format === "codex" ? "Codex" : session.format === "cursor" ? "Assistant" : "Claude"),
    title: options.title || "Replay",
    description: options.description || "",
    ogImage: options.ogImage || "",
    bookmarks: remapBookmarks(options.bookmarks || [], session.workingTurns, excludedSet),
    minified: false,
    compress: options.compress !== false,
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// Filesystem browsing
// ---------------------------------------------------------------------------

/** Ensure a path is under $HOME to prevent filesystem traversal. */
function assertUnderHome(targetPath) {
  const resolved = resolve(targetPath);
  const home = homedir();
  if (!resolved.startsWith(home + "/") && resolved !== home) {
    const err = new Error("Access denied: path must be under your home directory");
    err.code = "EACCES";
    throw err;
  }
  return resolved;
}

/** Browse a directory — returns dirs + .jsonl files. */
function browseDirectory(dirPath) {
  const resolved = assertUnderHome(dirPath);
  const entries = readdirSync(resolved);
  const dirs = [];
  const files = [];

  for (const name of entries) {
    if (name.startsWith(".")) continue;
    const fullPath = join(resolved, name);
    try {
      const stat = statSync(fullPath);
      if (stat.isDirectory()) {
        dirs.push({ name, path: fullPath });
      } else if (name.endsWith(".jsonl")) {
        files.push({ name, path: fullPath, date: stat.mtime.toISOString() });
      }
    } catch { /* skip inaccessible entries */ }
  }

  dirs.sort((a, b) => a.name.localeCompare(b.name));
  files.sort((a, b) => b.date.localeCompare(a.date));

  const parent = dirname(resolved);
  return { path: resolved, parent: parent !== resolved ? parent : null, dirs, files };
}

/** Discover session folders under Claude Code and Cursor project dirs. */
function discoverSessions() {
  const home = homedir();
  const groups = [];

  // Claude Code: ~/.claude/projects/<project>/*.jsonl
  const claudeBase = join(home, ".claude", "projects");
  try {
    const projects = readdirSync(claudeBase).filter((d) => {
      try { return statSync(join(claudeBase, d)).isDirectory(); } catch { return false; }
    });
    const claudeGroup = { name: "Claude Code", projects: [] };
    for (const proj of projects.sort()) {
      const projPath = join(claudeBase, proj);
      const files = readdirSync(projPath).filter((f) => f.endsWith(".jsonl")).sort().reverse();
      if (files.length === 0) continue;
      const parts = proj.replace(/^-+/, "").split("-");
      const displayName = parts.length > 1 ? parts.slice(-2).join("-") : parts[0];
      claudeGroup.projects.push({
        name: displayName,
        dirName: proj,
        sessions: files.map((f) => {
          const fullPath = join(projPath, f);
          let date = null;
          try { date = statSync(fullPath).mtime.toISOString(); } catch { /* ignore */ }
          return { file: f, path: fullPath, date };
        }),
      });
    }
    if (claudeGroup.projects.length > 0) groups.push(claudeGroup);
  } catch { /* directory doesn't exist */ }

  // Cursor: ~/.cursor/projects/<project>/agent-transcripts/<id>/transcript.jsonl
  const cursorBase = join(home, ".cursor", "projects");
  try {
    const projects = readdirSync(cursorBase).filter((d) => {
      try { return statSync(join(cursorBase, d)).isDirectory(); } catch { return false; }
    });
    const cursorGroup = { name: "Cursor", projects: [] };
    for (const proj of projects.sort()) {
      const transcriptsDir = join(cursorBase, proj, "agent-transcripts");
      let ids;
      try { ids = readdirSync(transcriptsDir); } catch { continue; }
      const cursorSessions = [];
      for (const id of ids.sort().reverse()) {
        const idDir = join(transcriptsDir, id);
        try { if (!statSync(idDir).isDirectory()) continue; } catch { continue; }
        // Try transcript.jsonl first, then <uuid>.jsonl
        let filePath = join(idDir, "transcript.jsonl");
        try {
          statSync(filePath);
        } catch {
          filePath = join(idDir, id + ".jsonl");
          try { statSync(filePath); } catch { continue; }
        }
        try {
          const stat = statSync(filePath);
          cursorSessions.push({ file: id, path: filePath, date: stat.mtime.toISOString() });
        } catch { continue; }
      }
      if (cursorSessions.length === 0) continue;
      const parts = proj.replace(/^-+/, "").split("-");
      const displayName = parts.length > 1 ? parts.slice(-2).join("-") : parts[0];
      cursorGroup.projects.push({ name: displayName, dirName: proj, sessions: cursorSessions });
    }
    if (cursorGroup.projects.length > 0) groups.push(cursorGroup);
  } catch { /* directory doesn't exist */ }

  // Codex CLI: ~/.codex/sessions/<YYYY>/<MM>/<DD>/rollout-*.jsonl
  const codexBase = join(home, ".codex", "sessions");
  try {
    const codexGroup = { name: "Codex CLI", projects: [] };
    // Walk year/month/day directories
    for (const year of readdirSync(codexBase).sort().reverse()) {
      const yearPath = join(codexBase, year);
      try { if (!statSync(yearPath).isDirectory()) continue; } catch { continue; }
      for (const month of readdirSync(yearPath).sort().reverse()) {
        const monthPath = join(yearPath, month);
        try { if (!statSync(monthPath).isDirectory()) continue; } catch { continue; }
        for (const day of readdirSync(monthPath).sort().reverse()) {
          const dayPath = join(monthPath, day);
          try { if (!statSync(dayPath).isDirectory()) continue; } catch { continue; }
          const files = readdirSync(dayPath).filter((f) => f.endsWith(".jsonl")).sort().reverse();
          if (files.length === 0) continue;
          codexGroup.projects.push({
            name: `${year}-${month}-${day}`,
            dirName: `${year}/${month}/${day}`,
            sessions: files.map((f) => {
              const fullPath = join(dayPath, f);
              let date = null;
              try { date = statSync(fullPath).mtime.toISOString(); } catch { /* ignore */ }
              return { file: f, path: fullPath, date };
            }),
          });
        }
      }
    }
    if (codexGroup.projects.length > 0) groups.push(codexGroup);
  } catch { /* directory doesn't exist */ }

  return groups;
}

// ---------------------------------------------------------------------------
// Git helpers
// ---------------------------------------------------------------------------

/** Run a git command in a directory, returns stdout or null on error. */
function gitExec(cwd, args) {
  return new Promise((resolve) => {
    execFile("git", args, { cwd, timeout: 5000, maxBuffer: 1024 * 1024 }, (err, stdout) => {
      if (err) return resolve(null);
      resolve(stdout.trim());
    });
  });
}

/** Get basic git info for a project path. */
async function getGitInfo(projectPath) {
  if (!existsSync(projectPath)) return null;

  const isRepo = await gitExec(projectPath, ["rev-parse", "--is-inside-work-tree"]);
  if (isRepo !== "true") return null;

  const [branch, remotesRaw, branchesRaw, statusRaw] = await Promise.all([
    gitExec(projectPath, ["rev-parse", "--abbrev-ref", "HEAD"]),
    gitExec(projectPath, ["remote", "-v"]),
    gitExec(projectPath, ["branch", "-a", "--no-color"]),
    gitExec(projectPath, ["status", "--porcelain", "-b"]),
  ]);

  const branches = branchesRaw ? branchesRaw.split("\n").filter(l => l.trim()) : [];
  const localBranches = branches.filter(b => !b.trim().startsWith("remotes/"));
  const remoteBranches = branches.filter(b => b.trim().startsWith("remotes/"));

  // Parse remotes
  const remotes = [];
  const seen = new Set();
  for (const line of (remotesRaw || "").split("\n")) {
    const m = line.match(/^(\S+)\s+(\S+)\s+\((\w+)\)/);
    if (m && !seen.has(m[1])) {
      seen.add(m[1]);
      remotes.push({ name: m[1], url: m[2] });
    }
  }

  // Parse status
  const statusLines = (statusRaw || "").split("\n").filter(l => l.trim());
  const branchLine = statusLines[0] || "";
  const changes = statusLines.slice(1);
  const modified = changes.filter(l => l.startsWith(" M") || l.startsWith("M ")).length;
  const added = changes.filter(l => l.startsWith("A ") || l.startsWith("??")).length;
  const deleted = changes.filter(l => l.startsWith("D ") || l.startsWith(" D")).length;

  return {
    isRepo: true,
    branch: branch || "unknown",
    localBranchCount: localBranches.length,
    remoteBranchCount: remoteBranches.length,
    localBranches: localBranches.map(b => b.replace(/^\*?\s*/, "").trim()),
    remotes,
    hasRemote: remotes.length > 0,
    status: { modified, added, deleted, clean: changes.length === 0, total: changes.length },
    branchLine,
  };
}

/** Get detailed git info for the Git tab. */
async function getGitDetails(projectPath) {
  const info = await getGitInfo(projectPath);
  if (!info) return null;

  const [commitCountRaw, logRaw, graphRaw] = await Promise.all([
    gitExec(projectPath, ["rev-list", "--count", "HEAD"]),
    gitExec(projectPath, ["log", "--oneline", "-30", "--no-color"]),
    gitExec(projectPath, ["log", "--graph", "--oneline", "--all", "--decorate", "-50", "--no-color"]),
  ]);

  const commitCount = parseInt(commitCountRaw) || 0;
  const recentCommits = (logRaw || "").split("\n").filter(l => l.trim()).map(line => {
    const m = line.match(/^([0-9a-f]+)\s+(.*)/);
    return m ? { hash: m[1], message: m[2] } : { hash: "", message: line };
  });

  return {
    ...info,
    commitCount,
    recentCommits,
    graph: graphRaw || "",
  };
}

// ---------------------------------------------------------------------------
// Project dashboard helpers
// ---------------------------------------------------------------------------

/**
 * Decode a Claude projects directory name back to the original filesystem path.
 * e.g. "-Users-foo-work-myproject" → "/Users/foo/work/myproject"
 * Uses filesystem probing to handle ambiguous dashes (e.g. usernames containing dashes).
 */
function claudeDirToProjectPath(dirName) {
  const parts = dirName.replace(/^-+/, "").split("-");
  // Greedily build the path, checking which segments exist on disk
  let path = "";
  let i = 0;
  while (i < parts.length) {
    // Try progressively longer dash-joined segments
    let found = false;
    for (let end = i + 1; end <= parts.length; end++) {
      const segment = parts.slice(i, end).join("-");
      const candidate = path + "/" + segment;
      // If this is not the last segment, check if it exists as a directory
      if (end < parts.length) {
        try {
          if (statSync(candidate).isDirectory()) {
            path = candidate;
            i = end;
            found = true;
            break;
          }
        } catch { /* doesn't exist, try longer segment */ }
      } else {
        // Last segment — accept it (might be a file or dir)
        path = candidate;
        i = end;
        found = true;
        break;
      }
    }
    if (!found) {
      // Fallback: just use the single part
      path += "/" + parts[i];
      i++;
    }
  }
  return path;
}

/** Discover projects grouped by source, with metadata. */
function discoverProjects() {
  const home = homedir();
  const projects = [];

  // Claude Code projects
  const claudeBase = join(home, ".claude", "projects");
  try {
    const dirs = readdirSync(claudeBase).filter((d) => {
      try { return statSync(join(claudeBase, d)).isDirectory(); } catch { return false; }
    });
    for (const dir of dirs) {
      const projPath = join(claudeBase, dir);
      const files = readdirSync(projPath).filter((f) => f.endsWith(".jsonl"));
      if (files.length === 0) continue;
      // Find latest activity
      let lastActivity = null;
      for (const f of files) {
        try {
          const mtime = statSync(join(projPath, f)).mtime;
          if (!lastActivity || mtime > lastActivity) lastActivity = mtime;
        } catch { /* ignore */ }
      }
      const realPath = claudeDirToProjectPath(dir);
      const displayName = basename(realPath);
      projects.push({
        source: "claude",
        dirName: dir,
        name: displayName,
        path: realPath,
        claudeProjectPath: projPath,
        sessionCount: files.length,
        lastActivity: lastActivity ? lastActivity.toISOString() : null,
      });
    }
  } catch { /* directory doesn't exist */ }

  // Sort by last activity descending
  projects.sort((a, b) => (b.lastActivity || "").localeCompare(a.lastActivity || ""));
  return projects;
}

/** Get detailed project information including CLAUDE.md, MEMORY.md, and session previews. */
function getProjectDetails(source, dirName) {
  const home = homedir();

  if (source === "claude") {
    const projPath = join(home, ".claude", "projects", dirName);
    if (!existsSync(projPath)) throw new Error("Project not found");

    const realPath = claudeDirToProjectPath(dirName);

    // Read CLAUDE.md from the actual project directory
    let claudeMd = null;
    const claudeMdPath = join(realPath, "CLAUDE.md");
    try { if (existsSync(claudeMdPath)) claudeMd = readFileSync(claudeMdPath, "utf-8"); } catch { /* ignore */ }

    // Read MEMORY.md from the claude project directory
    let memoryMd = null;
    const memoryMdPath = join(projPath, "memory", "MEMORY.md");
    try { if (existsSync(memoryMdPath)) memoryMd = readFileSync(memoryMdPath, "utf-8"); } catch { /* ignore */ }

    // List sessions with previews
    const files = readdirSync(projPath).filter((f) => f.endsWith(".jsonl")).sort().reverse();
    const sessionList = [];
    for (const file of files) {
      const fullPath = join(projPath, file);
      let date = null;
      let size = 0;
      try {
        const stat = statSync(fullPath);
        date = stat.mtime.toISOString();
        size = stat.size;
      } catch { /* ignore */ }

      // Quick preview: read lines to get user messages, timestamps, turn count
      let preview = "";
      let turnCount = 0;
      let firstTimestamp = null;
      let lastTimestamp = null;
      const userPreviews = []; // first 3 user messages for hover preview
      try {
        const content = readFileSync(fullPath, "utf-8");
        const lines = content.split("\n").filter((l) => l.trim());
        for (const line of lines) {
          try {
            const entry = JSON.parse(line);
            // Track timestamps
            if (entry.timestamp) {
              if (!firstTimestamp) firstTimestamp = entry.timestamp;
              lastTimestamp = entry.timestamp;
            }
            if (entry.type === "human" || entry.role === "human" || entry.type === "user" || entry.role === "user") {
              turnCount++;
              let userText = "";
              if (typeof entry.message === "string") {
                userText = entry.message;
              } else if (entry.message?.content) {
                const contentArr = Array.isArray(entry.message.content) ? entry.message.content : [entry.message.content];
                for (const c of contentArr) {
                  if (typeof c === "string") { userText = c; break; }
                  if (c.type === "text" && c.text) { userText = c.text; break; }
                }
              }
              // Clean system tags
              userText = userText.replace(/<system-reminder>[\s\S]*?<\/system-reminder>/g, "").trim();
              if (!preview && userText) preview = userText.slice(0, 150);
              if (userPreviews.length < 3 && userText) {
                userPreviews.push({ turn: turnCount, text: userText.slice(0, 200) });
              }
            }
          } catch { /* skip bad lines */ }
        }
      } catch { /* ignore read errors */ }

      // Compute duration
      let duration = null;
      if (firstTimestamp && lastTimestamp) {
        duration = new Date(lastTimestamp).getTime() - new Date(firstTimestamp).getTime();
      }

      const sessionId = file.replace(/\.jsonl$/, "");
      sessionList.push({
        sessionId,
        file,
        path: fullPath,
        date,
        size,
        turnCount,
        duration,
        preview: preview.slice(0, 120),
        userPreviews,
      });
    }

    // Aggregate stats
    const totalTurns = sessionList.reduce((s, x) => s + (x.turnCount || 0), 0);
    const totalSize = sessionList.reduce((s, x) => s + (x.size || 0), 0);
    const dates = sessionList.map((s) => s.date).filter(Boolean).sort();

    return {
      source,
      dirName,
      name: realPath,
      claudeProjectPath: projPath,
      claudeMd,
      memoryMd,
      sessions: sessionList,
      stats: {
        totalSessions: sessionList.length,
        totalTurns,
        totalSize,
        dateRange: dates.length > 0 ? { first: dates[0], last: dates[dates.length - 1] } : null,
      },
    };
  }

  throw new Error("Unsupported source: " + source);
}

/** Compute detailed statistics for a parsed session. */
function computeSessionStats(turns) {
  const stats = {
    turnCount: turns.length,
    totalBlocks: 0,
    textBlocks: 0,
    thinkingBlocks: 0,
    toolUseBlocks: 0,
    toolBreakdown: {},
    firstTimestamp: null,
    lastTimestamp: null,
    duration: null,
    avgBlocksPerTurn: 0,
    longestTurn: { index: 0, blockCount: 0 },
    userCharacters: 0,
    assistantCharacters: 0,
    thinkingCharacters: 0,
    errorCount: 0,
    // Detailed tool data
    bashCommands: [],    // { command, turn, is_error }
    filesRead: [],       // { path, turn }
    filesEdited: [],     // { path, turn, tool }  (Edit or Write)
    agents: [],          // { prompt, description, turn, mode, subagent_type }
    plans: [],           // { content, turn }  (plan mode entries)
    teams: [],           // { action, turn, input }
    userMessages: [],    // { text, turn }
    assistantTexts: [],  // { text, turn }
  };

  for (const turn of turns) {
    if (turn.timestamp) {
      if (!stats.firstTimestamp) stats.firstTimestamp = turn.timestamp;
      stats.lastTimestamp = turn.timestamp;
    }
    if (turn.user_text) {
      stats.userCharacters += turn.user_text.length;
      stats.userMessages.push({ text: turn.user_text, turn: turn.index });
    }

    const blockCount = turn.blocks ? turn.blocks.length : 0;
    stats.totalBlocks += blockCount;
    if (blockCount > stats.longestTurn.blockCount) {
      stats.longestTurn = { index: turn.index, blockCount };
    }

    for (const block of turn.blocks || []) {
      if (block.kind === "text") {
        stats.textBlocks++;
        const txt = block.text || "";
        stats.assistantCharacters += txt.length;
        if (txt.trim()) stats.assistantTexts.push({ text: txt, turn: turn.index });
      } else if (block.kind === "thinking") {
        stats.thinkingBlocks++;
        stats.thinkingCharacters += (block.text || "").length;
      } else if (block.kind === "tool_use" && block.tool_call) {
        stats.toolUseBlocks++;
        const tc = block.tool_call;
        const name = tc.name || "unknown";
        const input = tc.input || {};
        stats.toolBreakdown[name] = (stats.toolBreakdown[name] || 0) + 1;
        if (tc.is_error) stats.errorCount++;
        if (tc.resultTimestamp) {
          stats.lastTimestamp = tc.resultTimestamp;
        }

        // Collect detailed tool data
        if (name === "Bash" && input.command) {
          stats.bashCommands.push({
            command: input.command,
            turn: turn.index,
            is_error: !!tc.is_error,
            description: input.description || "",
          });
        }
        if (name === "Read" && input.file_path) {
          stats.filesRead.push({ path: input.file_path, turn: turn.index });
        }
        if ((name === "Edit" || name === "Write") && input.file_path) {
          stats.filesEdited.push({ path: input.file_path, turn: turn.index, tool: name });
        }
        if (name === "Agent") {
          stats.agents.push({
            description: input.description || "",
            prompt: input.prompt || "",
            turn: turn.index,
            mode: input.mode || "",
            subagent_type: input.subagent_type || "",
            run_in_background: !!input.run_in_background,
            model: input.model || "",
          });
        }
        // Team operations
        if (name === "TeamCreate" || name === "TeamDelete") {
          stats.teams.push({
            action: name,
            turn: turn.index,
            input: input,
          });
        }
        // Detect plan mode
        if (name === "EnterPlanMode" || name === "ExitPlanMode") {
          stats.plans.push({ tool: name, turn: turn.index });
        }
        if (name === "Write" && input.file_path && input.file_path.includes("/plans/")) {
          stats.plans.push({
            tool: "Write",
            path: input.file_path,
            content: input.content || "",
            turn: turn.index,
          });
        }
      }
      if (block.timestamp) {
        stats.lastTimestamp = block.timestamp;
      }
    }
  }

  if (stats.firstTimestamp && stats.lastTimestamp) {
    stats.duration = new Date(stats.lastTimestamp).getTime() - new Date(stats.firstTimestamp).getTime();
  }
  stats.avgBlocksPerTurn = turns.length > 0 ? Math.round(stats.totalBlocks / turns.length * 10) / 10 : 0;

  return stats;
}

/** Convert turns array to markdown string (server-side export). */
function turnsToMarkdown(turns, title) {
  const lines = ["# " + (title || "Claude Session"), ""];
  for (const turn of turns) {
    lines.push("---", "");
    let header = `## Turn ${turn.index}`;
    if (turn.timestamp) {
      header += ` — ${new Date(turn.timestamp).toISOString().replace("T", " ").replace(/\.\d+Z$/, " UTC")}`;
    }
    lines.push(header, "");
    if (turn.user_text) {
      lines.push("### User", "", turn.user_text, "");
    }
    if (turn.system_events && turn.system_events.length) {
      for (const ev of turn.system_events) lines.push(`> **System:** ${ev}`, "");
    }
    if (turn.blocks && turn.blocks.length) {
      lines.push("### Assistant", "");
      for (const block of turn.blocks) {
        if (block.kind === "text") {
          lines.push(block.text || "", "");
        } else if (block.kind === "thinking") {
          lines.push("<details>", "<summary>Thinking</summary>", "", block.text || "", "", "</details>", "");
        } else if (block.kind === "tool_use" && block.tool_call) {
          const tc = block.tool_call;
          lines.push(`#### Tool: ${tc.name || "unknown"}`);
          const inp = tc.input || {};
          if (tc.name === "Bash" && inp.command) {
            lines.push("", "```bash", inp.command, "```", "");
          } else if ((tc.name === "Edit" || tc.name === "Write") && inp.file_path) {
            lines.push("", `**File:** \`${inp.file_path}\``);
            if (tc.name === "Edit" && inp.old_string != null) {
              lines.push("", "```diff");
              for (const l of String(inp.old_string).split("\n")) lines.push("- " + l);
              for (const l of String(inp.new_string).split("\n")) lines.push("+ " + l);
              lines.push("```", "");
            } else if (inp.content != null) {
              lines.push("", "```", inp.content, "```", "");
            }
          } else {
            try { lines.push("", "```json", JSON.stringify(inp, null, 2), "```", ""); } catch { lines.push(""); }
          }
          if (tc.result != null) {
            lines.push(tc.is_error ? "**Error:**" : "**Result:**", "", "```", tc.result, "```", "");
          }
        }
      }
    }
  }
  return lines.join("\n");
}

// ---------------------------------------------------------------------------
// API route handler
// ---------------------------------------------------------------------------

async function handleApi(req, res, pathname) {
  // CSRF protection: reject cross-origin requests to the API.
  // The editor is served from 127.0.0.1, so legitimate requests have a
  // matching Origin or no Origin at all (same-origin, curl, etc.).
  const origin = req.headers.origin;
  if (origin) {
    try {
      const originHost = new URL(origin).hostname;
      if (originHost !== "127.0.0.1" && originHost !== "localhost") {
        return error(res, "Cross-origin requests are not allowed", 403);
      }
    } catch {
      return error(res, "Invalid Origin header", 403);
    }
  }

  // GET /api/sessions — list discovered sessions + home directory
  if (pathname === "/api/sessions" && req.method === "GET") {
    return json(res, { groups: discoverSessions(), homedir: homedir(), version: PKG.version });
  }

  // GET /api/themes — list available themes
  if (pathname === "/api/themes" && req.method === "GET") {
    return json(res, listThemes());
  }

  // POST /api/browse — browse a directory for .jsonl files
  if (pathname === "/api/browse" && req.method === "POST") {
    const body = await readBody(req);
    if (!body.path) return error(res, "Missing 'path' field");
    try {
      return json(res, browseDirectory(body.path));
    } catch (e) {
      const msg = e.code === "ENOENT" ? "Folder not found"
        : e.code === "EACCES" ? "Permission denied" : e.message;
      return error(res, msg, 400);
    }
  }

  // POST /api/load — parse a JSONL file (or return cached session)
  if (pathname === "/api/load" && req.method === "POST") {
    const body = await readBody(req);
    const filePath = body.path;
    if (!filePath) return error(res, "Missing 'path' field");
    try {
      assertUnderHome(filePath);
      // Reuse existing session for the same file
      for (const [existingId, s] of sessions) {
        if (s.sourcePath === filePath) {
          const hasEdits = JSON.stringify(s.workingTurns) !== JSON.stringify(s.originalTurns);
          return json(res, {
            sessionId: existingId,
            format: s.format,
            hasEdits,
            turns: summarizeTurns(s.workingTurns),
          });
        }
      }
      // New session
      const format = detectFormat(filePath);
      const turns = parseTranscript(filePath);
      const id = "s" + (++sessionCounter);
      sessions.set(id, {
        originalTurns: JSON.parse(JSON.stringify(turns)),
        workingTurns: turns,
        sourcePath: filePath,
        format,
      });
      return json(res, {
        sessionId: id,
        format,
        hasEdits: false,
        turns: summarizeTurns(turns),
      });
    } catch (e) {
      return error(res, `Failed to parse: ${e.message}`, 500);
    }
  }

  // POST /api/edit — update a turn's user text
  if (pathname === "/api/edit" && req.method === "POST") {
    const body = await readBody(req);
    const { sessionId, turnIndex, user_text } = body;
    const session = sessions.get(sessionId);
    if (!session) return error(res, "Unknown session", 404);
    const turn = session.workingTurns.find((t) => t.index === turnIndex);
    if (!turn) return error(res, `Turn ${turnIndex} not found`, 404);
    turn.user_text = user_text;
    const hasEdits = JSON.stringify(session.workingTurns) !== JSON.stringify(session.originalTurns);
    return json(res, { ok: true, hasEdits });
  }

  // POST /api/preview — render HTML for live preview
  if (pathname === "/api/preview" && req.method === "POST") {
    const body = await readBody(req);
    const { sessionId, options = {} } = body;
    const session = sessions.get(sessionId);
    if (!session) return error(res, "Unknown session", 404);
    const turns = prepareTurns(session, options);
    const html = render(turns, buildRenderOpts(options, session));
    return json(res, { html });
  }

  // POST /api/export — render HTML and serve as download
  if (pathname === "/api/export" && req.method === "POST") {
    const body = await readBody(req);
    const { sessionId, options = {} } = body;
    const session = sessions.get(sessionId);
    if (!session) return error(res, "Unknown session", 404);
    const turns = prepareTurns(session, options);
    const html = render(turns, buildRenderOpts(options, session, {
      minified: options.minified !== false,
      compress: options.compress !== false,
    }));
    const filename = (options.title || "replay").replace(/[^a-zA-Z0-9_-]/g, "_") + ".html";
    res.writeHead(200, {
      "Content-Type": "text/html; charset=utf-8",
      "Content-Disposition": `attachment; filename="${filename}"`,
      "Content-Length": Buffer.byteLength(html),
    });
    return res.end(html);
  }

  // POST /api/reset — restore working turns from original
  if (pathname === "/api/reset" && req.method === "POST") {
    const body = await readBody(req);
    const { sessionId } = body;
    const session = sessions.get(sessionId);
    if (!session) return error(res, "Unknown session", 404);
    session.workingTurns = JSON.parse(JSON.stringify(session.originalTurns));
    return json(res, { turns: summarizeTurns(session.workingTurns) });
  }

  // GET /api/projects — list all discovered projects with metadata
  if (pathname === "/api/projects" && req.method === "GET") {
    return json(res, discoverProjects());
  }

  // POST /api/projects/details — get project details (CLAUDE.md, MEMORY.md, sessions with previews)
  if (pathname === "/api/projects/details" && req.method === "POST") {
    const body = await readBody(req);
    const { source, dirName } = body;
    if (!source || !dirName) return error(res, "Missing source or dirName");
    try {
      return json(res, getProjectDetails(source, dirName));
    } catch (e) {
      return error(res, e.message, 500);
    }
  }

  // POST /api/session-stats — compute detailed stats for a session
  if (pathname === "/api/session-stats" && req.method === "POST") {
    const body = await readBody(req);
    const filePath = body.path;
    if (!filePath) return error(res, "Missing 'path' field");
    try {
      assertUnderHome(filePath);
      const turns = parseTranscript(filePath);
      const stats = computeSessionStats(turns);
      return json(res, stats);
    } catch (e) {
      return error(res, `Failed to compute stats: ${e.message}`, 500);
    }
  }

  // POST /api/export-md — generate markdown for a session and serve as download
  if (pathname === "/api/export-md" && req.method === "POST") {
    const body = await readBody(req);
    const filePath = body.path;
    if (!filePath) return error(res, "Missing 'path' field");
    try {
      assertUnderHome(filePath);
      const turns = parseTranscript(filePath);
      const md = turnsToMarkdown(turns, body.title || basename(filePath, ".jsonl"));
      const filename = (body.title || "session").replace(/[^a-zA-Z0-9_-]/g, "_") + ".md";
      res.writeHead(200, {
        "Content-Type": "text/markdown; charset=utf-8",
        "Content-Disposition": `attachment; filename="${filename}"`,
        "Content-Length": Buffer.byteLength(md),
      });
      return res.end(md);
    } catch (e) {
      return error(res, `Failed to export: ${e.message}`, 500);
    }
  }

  // POST /api/transcript — full turn data for transcript viewer (not truncated)
  if (pathname === "/api/transcript" && req.method === "POST") {
    const body = await readBody(req);
    const filePath = body.path;
    if (!filePath) return error(res, "Missing 'path' field");
    try {
      assertUnderHome(filePath);
      const turns = parseTranscript(filePath);
      // Return full data but strip very large fields to keep response reasonable
      const fullTurns = turns.map((t) => ({
        index: t.index,
        user_text: t.user_text,
        timestamp: t.timestamp,
        system_events: t.system_events || [],
        blocks: t.blocks.map((b) => {
          if (b.kind === "tool_use" && b.tool_call) {
            const tc = b.tool_call;
            const input = tc.input || {};
            // For tool calls, include structured input for good preview
            return {
              kind: b.kind,
              tool_call: {
                name: tc.name,
                input: input,
                result: tc.result ? (tc.result.length > 2000 ? tc.result.slice(0, 2000) + "..." : tc.result) : null,
                is_error: tc.is_error,
              },
            };
          }
          return { kind: b.kind, text: b.text || "" };
        }),
      }));
      return json(res, { turns: fullTurns });
    } catch (e) {
      return error(res, `Failed to load transcript: ${e.message}`, 500);
    }
  }

  // POST /api/search — search across all sessions in a project
  if (pathname === "/api/search" && req.method === "POST") {
    const body = await readBody(req);
    const { dirName, query, projectName } = body;
    if (!dirName || !query || query.length < 2) return json(res, { results: [] });
    try {
      const home = homedir();
      const projPath = join(home, ".claude", "projects", dirName);
      if (!existsSync(projPath)) return json(res, { results: [] });
      const pName = projectName || basename(claudeDirToProjectPath(dirName));

      const files = readdirSync(projPath).filter((f) => f.endsWith(".jsonl")).sort().reverse();
      const results = [];
      const queryLower = query.toLowerCase();

      for (const file of files.slice(0, 30)) {
        if (results.length >= 50) break;
        const fullPath = join(projPath, file);
        try {
          const content = readFileSync(fullPath, "utf-8");
          const lines = content.split("\n").filter((l) => l.trim());
          let turnIdx = 0;
          for (const line of lines) {
            if (results.length >= 50) break;
            try {
              const entry = JSON.parse(line);
              const isUser = entry.type === "human" || entry.role === "human" || entry.type === "user" || entry.role === "user";
              if (isUser) {
                turnIdx++;
                let text = "";
                if (typeof entry.message === "string") text = entry.message;
                else if (entry.message?.content) {
                  const arr = Array.isArray(entry.message.content) ? entry.message.content : [entry.message.content];
                  for (const c of arr) {
                    if (typeof c === "string") { text = c; break; }
                    if (c.type === "text" && c.text) { text = c.text; break; }
                  }
                }
                text = text.replace(/<system-reminder>[\s\S]*?<\/system-reminder>/g, "").trim();
                if (text.toLowerCase().includes(queryLower)) {
                  const sessionId = file.replace(/\.jsonl$/, "");
                  results.push({
                    project: pName,
                    sessionId: sessionId.slice(0, 8),
                    path: fullPath,
                    turn: turnIdx,
                    text: text.slice(0, 300),
                    role: "user",
                  });
                }
              }
              // Also search assistant text blocks
              if (entry.type === "assistant" || entry.role === "assistant") {
                const msg = entry.message;
                if (typeof msg === "string" && msg.toLowerCase().includes(queryLower)) {
                  const sessionId = file.replace(/\.jsonl$/, "");
                  results.push({
                    project: pName,
                    sessionId: sessionId.slice(0, 8),
                    path: fullPath,
                    turn: turnIdx,
                    text: msg.slice(0, 300),
                    role: "assistant",
                  });
                } else if (msg?.content && Array.isArray(msg.content)) {
                  for (const c of msg.content) {
                    if (results.length >= 50) break;
                    if (c.type === "text" && c.text && c.text.toLowerCase().includes(queryLower)) {
                      const sessionId = file.replace(/\.jsonl$/, "");
                      results.push({
                        project: pName,
                        sessionId: sessionId.slice(0, 8),
                        path: fullPath,
                        turn: turnIdx,
                        text: c.text.slice(0, 300),
                        role: "assistant",
                      });
                      break;
                    }
                  }
                }
              }
            } catch { /* skip */ }
          }
        } catch { /* skip file */ }
      }
      return json(res, { results });
    } catch (e) {
      return error(res, e.message, 500);
    }
  }

  // POST /api/render-replay — render player HTML for iframe embedding (not download)
  if (pathname === "/api/render-replay" && req.method === "POST") {
    const body = await readBody(req);
    const filePath = body.path;
    if (!filePath) return error(res, "Missing 'path' field");
    try {
      assertUnderHome(filePath);
      const format = detectFormat(filePath);
      const turns = parseTranscript(filePath);
      const themeName = body.theme || "tokyo-night";
      const html = render(turns, {
        speed: 1.0,
        showThinking: true,
        showToolCalls: true,
        theme: getThemeSafe(themeName),
        redactSecrets: true,
        redactRules: [],
        userLabel: "User",
        assistantLabel: format === "codex" ? "Codex" : format === "cursor" ? "Assistant" : "Claude",
        title: body.title || "",
        description: "",
        ogImage: "",
        bookmarks: [],
        minified: false,
        compress: true,
      });
      res.writeHead(200, {
        "Content-Type": "text/html; charset=utf-8",
        "Content-Length": Buffer.byteLength(html),
      });
      return res.end(html);
    } catch (e) {
      return error(res, `Failed to render: ${e.message}`, 500);
    }
  }

  // POST /api/git-info — basic git info for a project path
  if (pathname === "/api/git-info" && req.method === "POST") {
    const body = await readBody(req);
    if (!body.path) return error(res, "Missing 'path' field");
    try {
      const info = await getGitInfo(body.path);
      return json(res, info || { isRepo: false });
    } catch (e) {
      return json(res, { isRepo: false });
    }
  }

  // POST /api/git-details — detailed git info (branches, commits, graph)
  if (pathname === "/api/git-details" && req.method === "POST") {
    const body = await readBody(req);
    if (!body.path) return error(res, "Missing 'path' field");
    try {
      const details = await getGitDetails(body.path);
      return json(res, details || { isRepo: false });
    } catch (e) {
      return json(res, { isRepo: false });
    }
  }

  // POST /api/open — open a path in Finder or Terminal
  if (pathname === "/api/open" && req.method === "POST") {
    const body = await readBody(req);
    if (!body.path) return error(res, "Missing 'path' field");
    const target = body.path;
    // Only allow opening paths under home
    try { assertUnderHome(target); } catch { return error(res, "Access denied"); }

    if (body.action === "finder") {
      execFile("open", [target], () => {});
      return json(res, { ok: true });
    }
    if (body.action === "terminal") {
      // Try iTerm2 first, fall back to Terminal.app
      execFile("open", ["-a", "iTerm", target], (err) => {
        if (err) execFile("open", ["-a", "Terminal", target], () => {});
      });
      return json(res, { ok: true });
    }
    return error(res, "Unknown action: " + body.action);
  }

  return error(res, "Not found", 404);
}

// ---------------------------------------------------------------------------
// Server entry point
// ---------------------------------------------------------------------------

/**
 * Start the editor HTTP server.
 * Returns a promise that never resolves (keeps the caller waiting).
 * @param {number} port
 * @returns {Promise<void>}
 */
export function startEditor(port, { open = true, host = "127.0.0.1" } = {}) {
  const SHARED_CSS_PATH = new URL("../template/shared.css", import.meta.url);
  let sharedCss = "";
  try { sharedCss = readFileSync(SHARED_CSS_PATH, "utf-8"); } catch { /* */ }

  const themesJson = JSON.stringify({ version: PKG.version, themes: getAllThemes() });

  function injectShared(html) {
    return html
      .replace("/*SHARED_CSS*/", sharedCss)
      .replaceAll("/*THEMES_JSON*/", themesJson);
  }

  const rawEditorHtml = readFileSync(EDITOR_HTML_PATH, "utf-8");
  const editorHtml = injectShared(rawEditorHtml);
  const dashboardHtmlPath = new URL("../template/dashboard.html", import.meta.url);
  let dashboardHtml = "";
  try { dashboardHtml = injectShared(readFileSync(dashboardHtmlPath, "utf-8")); } catch { /* file may not exist yet */ }

  const server = createServer(async (req, res) => {
    const url = new URL(req.url, `http://${req.headers.host}`);
    const pathname = url.pathname;

    try {
      // Dashboard is the new landing page
      if (pathname === "/" && req.method === "GET") {
        const html = dashboardHtml || editorHtml;
        res.writeHead(200, {
          "Content-Type": "text/html; charset=utf-8",
          "Content-Length": Buffer.byteLength(html),
        });
        return res.end(html);
      }

      // Editor still accessible at /editor
      if (pathname === "/editor" && req.method === "GET") {
        res.writeHead(200, {
          "Content-Type": "text/html; charset=utf-8",
          "Content-Length": Buffer.byteLength(editorHtml),
        });
        return res.end(editorHtml);
      }

      // Replay wrapper page: /replay?path=<encoded-path>
      if (pathname === "/replay" && req.method === "GET") {
        const replayHtmlPath = new URL("../template/replay.html", import.meta.url);
        let replayHtml = "";
        try { replayHtml = injectShared(readFileSync(replayHtmlPath, "utf-8")); } catch { /* */ }
        if (replayHtml) {
          res.writeHead(200, {
            "Content-Type": "text/html; charset=utf-8",
            "Content-Length": Buffer.byteLength(replayHtml),
          });
          return res.end(replayHtml);
        }
      }

      // Docs page: /docs
      if (pathname === "/docs" && req.method === "GET") {
        const docsHtmlPath = new URL("../template/docs.html", import.meta.url);
        let docsHtml = "";
        try { docsHtml = injectShared(readFileSync(docsHtmlPath, "utf-8")); } catch { /* */ }
        if (docsHtml) {
          res.writeHead(200, { "Content-Type": "text/html; charset=utf-8", "Content-Length": Buffer.byteLength(docsHtml) });
          return res.end(docsHtml);
        }
      }

      // Serve rendered player HTML for iframe embedding: /api/render-replay
      if (pathname === "/api/render-replay" && req.method === "POST") {
        return await handleApi(req, res, pathname);
      }

      if (pathname.startsWith("/api/")) {
        return await handleApi(req, res, pathname);
      }

      res.writeHead(404, { "Content-Type": "text/plain" });
      res.end("Not found");
    } catch (e) {
      console.error("Server error:", e);
      if (!res.headersSent) {
        error(res, "Internal server error", 500);
      }
    }
  });

  return new Promise((_resolve) => {
    server.on("error", (err) => {
      if (err.code === "EADDRINUSE") {
        console.error(`Error: port ${port} is already in use. Stop the other process or use --port to pick a different port.`);
      } else {
        console.error(`Error: ${err.message}`);
      }
      process.exit(1);
    });
    server.listen(port, host, () => {
      const url = `http://127.0.0.1:${port}`;
      console.log(`claude-replay editor running at ${url}`);
      console.log("Press Ctrl+C to stop.\n");
      if (open) {
        const cmd = process.platform === "darwin" ? "open"
          : process.platform === "win32" ? "start" : "xdg-open";
        execFile(cmd, [url], () => {});
      }
    });
  });
}
