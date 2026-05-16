import Foundation

/// Owns the lifetime of the Node sidecar subprocess for one chat session.
///
/// Architecture:
///  - `start(...)` spawns `node sidecar.js …` with a stdin pipe (we write
///    line-delimited JSON commands) and a stdout pipe (we read line-
///    delimited JSON events). Returns an `AsyncThrowingStream<StreamEvent>`
///    that yields each parsed line and finishes when the process exits.
///  - `send(_:)` writes one user message as `{"type":"send","text":...}`.
///  - `stop()` writes `{"type":"stop"}`, gives the process up to 1 s to
///    exit cleanly, then `terminate()`s and `kill`s if it's still alive.
///
/// Concurrency: the actor serialises stdin writes and any state mutation;
/// stdout reading runs on a detached `Task` that yields into the async
/// stream owned by the actor.
actor ClaudeAgent {

    // MARK: - Public API

    struct StartOptions: Sendable {
        var sessionPath: String          // ~/.claude/projects/<dir>/<sid>.jsonl
        var workingDirectory: URL        // real project path (--cwd for the SDK)
        var permissionMode: String       // "default" | "plan" | "acceptEdits" | …
        /// G6 — explicit tool allow-list. `nil` = SDK default (everything).
        /// An empty array sandboxes the agent to zero tools.
        var allowedTools: [String]? = nil
        /// G6 — tool deny-list. Wins over `allowedTools` per SDK semantics.
        var disallowedTools: [String]? = nil
        var includePartialMessages: Bool // verbose toggle
        var skeleton: Bool               // step 4 path: bypass SDK, just echo
        /// Extra environment variables to layer over the inherited PATH/etc.
        /// Used to forward `CLAUDE_CONFIG_DIR` so the sidecar resolves the
        /// right account dir (`~/.claude`, `~/.claude-yahoo`, …) when
        /// multi-account is in play.
        var env: [String: String] = [:]
        /// G4 — SDK model id (e.g. "claude-opus-4-7"). `nil` = SDK default.
        var model: String? = nil
        /// G5 — appended to the SDK's default system prompt for this
        /// session. `nil` = SDK default only.
        var customSystemPrompt: String? = nil
    }

    enum AgentError: LocalizedError {
        case alreadyRunning
        case notRunning
        case spawnFailed(String)
        var errorDescription: String? {
            switch self {
            case .alreadyRunning: return "ClaudeAgent already started"
            case .notRunning:     return "ClaudeAgent is not running"
            case .spawnFailed(let m): return "Failed to spawn sidecar: \(m)"
            }
        }
    }

    private var process: Process?
    private var stdinPipe: Pipe?
    private var continuation: AsyncThrowingStream<StreamEvent, Error>.Continuation?
    private var readerTask: Task<Void, Never>?

    /// Set true once we've received a `hello` frame with a protocol version
    /// we understand. Until then, agent_event frames are still forwarded
    /// (we don't gate them) but the watchdog won't kill the process for
    /// missing heartbeats — sidecar boot can take a beat under load.
    private var protocolValidated: Bool = false

    /// Last time we observed a heartbeat (or hello/ready). The watchdog
    /// compares against `Date.now` and tears the sidecar down if it falls
    /// behind by more than 90 s.
    private var lastHeartbeat: Date = .now

    /// Background task that polls `lastHeartbeat` and triggers `stop()`
    /// if the sidecar appears wedged.
    private var watchdogTask: Task<Void, Never>?

    /// Expected sidecar protocol version. Bump in lock-step with
    /// `PROTOCOL_VERSION` in `sidecar.js` if/when the wire format breaks.
    private static let expectedProtocolVersion = "1"

    /// Returns `true` if the process is currently running.
    var isRunning: Bool { process?.isRunning == true }

    /// Spawn the sidecar and return a stream of events. Caller should
    /// `for try await event in stream { … }` to receive them.
    func start(options: StartOptions) async throws -> AsyncThrowingStream<StreamEvent, Error> {
        guard process == nil else { throw AgentError.alreadyRunning }

        let nodeURL = try SidecarLocator.nodeBinary()
        let scriptURL = try SidecarLocator.bundledSidecarScript()

        let args = buildArgs(scriptPath: scriptURL.path, options: options)

        let proc = Process()
        proc.executableURL = nodeURL
        proc.arguments = args
        proc.currentDirectoryURL = options.workingDirectory
        // Inherit the user's PATH so the SDK can shell out to `claude`.
        var env = ProcessInfo.processInfo.environment
        if let claude = try? SidecarLocator.claudeBinary() {
            // Surface the resolved claude binary to the sidecar via env in
            // case the SDK probes for one. Harmless when unused.
            env["CLAUDE_CODE_BINARY"] = claude.path
        }
        // Caller-supplied env wins (e.g. `CLAUDE_CONFIG_DIR` for multi-account).
        for (k, v) in options.env { env[k] = v }
        proc.environment = env

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr

        let stream = AsyncThrowingStream<StreamEvent, Error> { continuation in
            self.continuation = continuation
        }

        do {
            try proc.run()
        } catch {
            continuation?.finish(throwing: AgentError.spawnFailed(error.localizedDescription))
            continuation = nil
            throw AgentError.spawnFailed(error.localizedDescription)
        }

        self.process = proc
        self.stdinPipe = stdin
        self.lastHeartbeat = .now
        self.protocolValidated = false
        startHeartbeatWatchdog()

        // stdout reader — line-buffered, parses each line, yields events.
        // Detached so `start(...)` returns the stream immediately while the
        // pump runs in the background.
        readerTask = Task.detached { [weak self] in
            await Self.pumpStdout(handle: stdout.fileHandleForReading) { event in
                Task { await self?.yield(event) }
            }
            // Reader EOF — process closed stdout. Wait for exit and finish.
            proc.waitUntilExit()
            await self?.handleProcessExit(code: Int(proc.terminationStatus))
        }

        // Best-effort: drain stderr to avoid filling the pipe and stalling
        // the child. Each non-empty line becomes a soft .error event.
        Task.detached { [weak self] in
            await Self.pumpStdout(handle: stderr.fileHandleForReading) { line in
                if case .error(let msg) = line, !msg.isEmpty {
                    Task { await self?.yield(.error(message: msg)) }
                } else if case .unknown(let raw) = line, !raw.isEmpty {
                    Task { await self?.yield(.error(message: raw)) }
                }
            }
        }

        return stream
    }

    /// Write `{"type":"send","text":...}` to the sidecar's stdin.
    func send(_ text: String) async throws {
        guard let stdin = stdinPipe, isRunning else { throw AgentError.notRunning }
        let payload: [String: String] = ["type": "send", "text": text]
        let data = try JSONSerialization.data(withJSONObject: payload) + Data([0x0a])
        try stdin.fileHandleForWriting.write(contentsOf: data)
    }

    /// Send `{"type":"stop"}`, give the process 1 s to exit, then terminate.
    func stop() async {
        guard let proc = process else { return }
        if let stdin = stdinPipe, isRunning {
            let payload = #"{"type":"stop"}"# + "\n"
            try? stdin.fileHandleForWriting.write(contentsOf: Data(payload.utf8))
            try? stdin.fileHandleForWriting.close()
        }
        // Wait up to 1 s for clean exit.
        for _ in 0..<10 {
            if !proc.isRunning { break }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        if proc.isRunning { proc.terminate() }
        // If it survived terminate() too, cancellation will hit on the
        // detached reader and we'll still finish() the stream.
        readerTask?.cancel()
        watchdogTask?.cancel()
        watchdogTask = nil
        finishStream()
        process = nil
        stdinPipe = nil
    }

    /// Spawn a heartbeat watchdog. Polls every 45 s; if no heartbeat has
    /// arrived in 90 s the sidecar is assumed wedged and torn down. The
    /// reader task will then propagate the EOF to consumers.
    private func startHeartbeatWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 45_000_000_000)
                guard let self else { return }
                let stale = await self.heartbeatIsStale(thresholdSeconds: 90)
                if stale {
                    await self.handleWatchdogTimeout()
                    break
                }
            }
        }
    }

    private func heartbeatIsStale(thresholdSeconds: TimeInterval) -> Bool {
        guard isRunning else { return false }
        return Date.now.timeIntervalSince(lastHeartbeat) > thresholdSeconds
    }

    private func handleWatchdogTimeout() async {
        // Surface the timeout so consumers see it before the stream finishes.
        let msg = "sidecar heartbeat lost — killing process"
        continuation?.yield(.error(message: msg))
        await stop()
    }

    // MARK: - Private

    /// Build the argv vector for `node sidecar.js …` from `StartOptions`.
    private func buildArgs(scriptPath: String, options: StartOptions) -> [String] {
        var args: [String] = [scriptPath]
        if options.skeleton {
            args.append("--skeleton")
            return args
        }
        // Real-agent mode (filled in in step 5; the flags match sidecar.js).
        let sid = (options.sessionPath as NSString).lastPathComponent
            .replacingOccurrences(of: ".jsonl", with: "")
        args += ["--resume", sid]
        args += ["--cwd", options.workingDirectory.path]
        args += ["--permission-mode", options.permissionMode]
        // G6 — forward allow/deny lists as comma-separated argv. Empty
        // allow-list still goes through so the sidecar sandboxes the
        // agent (vs. `nil` which means "SDK default = everything").
        if let tools = options.allowedTools {
            args += ["--allowed-tools", tools.joined(separator: ",")]
        }
        if let tools = options.disallowedTools, !tools.isEmpty {
            args += ["--disallowed-tools", tools.joined(separator: ",")]
        }
        if options.includePartialMessages {
            args += ["--partial-messages"]
        }
        if let model = options.model, !model.isEmpty {
            args += ["--model", model]
        }
        if let prompt = options.customSystemPrompt, !prompt.isEmpty {
            args += ["--custom-system-prompt", prompt]
        }
        return args
    }

    private func yield(_ event: StreamEvent) {
        // Intercept sidecar-internal events for liveness/protocol bookkeeping
        // before forwarding to consumers. We still forward each event so
        // tests and verbose UI can observe them; we just side-effect first.
        switch event {
        case .hello(let proto, _, _):
            lastHeartbeat = .now
            if proto == Self.expectedProtocolVersion {
                protocolValidated = true
            } else {
                let msg = "sidecar protocol mismatch: expected \(Self.expectedProtocolVersion), got \"\(proto)\""
                continuation?.yield(.error(message: msg))
                continuation?.yield(.exit(code: 1))
                finishStream()
                // Tear the process down; the reader task will hit EOF.
                Task { await self.stop() }
                return
            }
        case .heartbeat(let ts):
            lastHeartbeat = ts
        case .log:
            // No-op for now; the event is still forwarded so the UI / tests
            // can decide to surface it. Future: bridge to OSLog.
            break
        default:
            break
        }
        continuation?.yield(event)
        if case .exit = event {
            finishStream()
        }
    }

    private func handleProcessExit(code: Int) {
        // If the sidecar didn't emit its own exit event, synthesise one so
        // consumers get a deterministic terminator.
        if let cont = continuation {
            cont.yield(.exit(code: code))
            cont.finish()
            continuation = nil
        }
    }

    private func finishStream() {
        continuation?.finish()
        continuation = nil
    }

    /// Read `handle` line-by-line until EOF; for each non-empty line, decode
    /// via `StreamEvent.decode` and forward via `forward`. Lines that don't
    /// decode fall through as `.unknown` so the caller can still surface them.
    nonisolated private static func pumpStdout(
        handle: FileHandle,
        forward: @escaping @Sendable (StreamEvent) -> Void
    ) async {
        var buffer = Data()
        while true {
            let chunk = handle.availableData
            if chunk.isEmpty { break } // EOF
            buffer.append(chunk)
            while let nlIndex = buffer.firstIndex(of: 0x0a) {
                let lineData = buffer.subdata(in: 0..<nlIndex)
                buffer.removeSubrange(0...nlIndex)
                if let line = String(data: lineData, encoding: .utf8),
                   let event = StreamEvent.decode(line: line) {
                    forward(event)
                }
            }
        }
        // Flush any tail without trailing newline.
        if !buffer.isEmpty,
           let line = String(data: buffer, encoding: .utf8),
           let event = StreamEvent.decode(line: line) {
            forward(event)
        }
    }
}
