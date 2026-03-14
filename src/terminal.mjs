/**
 * WebSocket-based terminal server.
 * Spawns lazygit (or shell) in a PTY and streams to/from browser via WebSocket.
 */

import { WebSocketServer } from "ws";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

let ptySpawn = null;
try {
  const pty = require("node-pty");
  ptySpawn = pty.spawn;
} catch {
  /* not available */
}

/**
 * Attach a WebSocket terminal server to an existing HTTP server.
 * Handles upgrade requests on /ws/terminal?path=<project-path>&cmd=<command>
 */
export function attachTerminalWs(httpServer) {
  if (!ptySpawn) {
    console.log("node-pty not available — terminal WebSocket disabled");
    return;
  }

  const spawn = ptySpawn;

  const wss = new WebSocketServer({ noServer: true });

  httpServer.on("upgrade", (req, socket, head) => {
    const url = new URL(req.url, `http://${req.headers.host}`);
    if (url.pathname !== "/ws/terminal") {
      socket.destroy();
      return;
    }

    wss.handleUpgrade(req, socket, head, (ws) => {
      const cwd = url.searchParams.get("path") || process.env.HOME || "/";
      const cmd = url.searchParams.get("cmd") || "lazygit";
      const cols = parseInt(url.searchParams.get("cols")) || 120;
      const rows = parseInt(url.searchParams.get("rows")) || 40;

      let pty;
      try {
        // Try the requested command, fall back to shell
        const shell = process.env.SHELL || "/bin/sh";
        const args = cmd === "lazygit" ? [] : ["-c", cmd];
        const command = cmd === "lazygit" ? "lazygit" : shell;

        const dataDir = process.env.CLAUDE_REPLAY_DATA || "/tmp/claude-replay";
        pty = spawn(command, args, {
          name: "xterm-256color",
          cols,
          rows,
          cwd,
          env: {
            ...process.env,
            TERM: "xterm-256color",
            COLORTERM: "truecolor",
            XDG_CONFIG_HOME: dataDir + "/config",
            XDG_DATA_HOME: dataDir + "/data",
            XDG_STATE_HOME: dataDir + "/state",
          },
        });
      } catch (e) {
        // Fallback: open a shell if lazygit not found
        try {
          const shell = process.env.SHELL || "/bin/sh";
          pty = spawn(shell, [], {
            name: "xterm-256color",
            cols,
            rows,
            cwd,
            env: { ...process.env, TERM: "xterm-256color" },
          });
          // Send error message to terminal
          setTimeout(() => {
            ws.send(`\r\n\x1b[33m⚠ ${cmd} not found, opened shell instead.\x1b[0m\r\n\r\n`);
          }, 100);
        } catch (e2) {
          ws.send(`\r\nError: Could not start terminal: ${e2.message}\r\n`);
          ws.close();
          return;
        }
      }

      // PTY → WebSocket
      pty.onData((data) => {
        try { if (ws.readyState === 1) ws.send(data); } catch {}
      });

      pty.onExit(({ exitCode }) => {
        try {
          ws.send(`\r\n\x1b[90m[Process exited with code ${exitCode}]\x1b[0m\r\n`);
          ws.close();
        } catch {}
      });

      // WebSocket → PTY
      ws.on("message", (data) => {
        const msg = data.toString();
        // Handle resize messages: JSON { type: "resize", cols, rows }
        if (msg.startsWith("{")) {
          try {
            const parsed = JSON.parse(msg);
            if (parsed.type === "resize" && parsed.cols && parsed.rows) {
              pty.resize(parsed.cols, parsed.rows);
              return;
            }
          } catch {}
        }
        pty.write(msg);
      });

      ws.on("close", () => {
        try { pty.kill(); } catch {}
      });

      ws.on("error", () => {
        try { pty.kill(); } catch {}
      });
    });
  });

  return wss;
}
