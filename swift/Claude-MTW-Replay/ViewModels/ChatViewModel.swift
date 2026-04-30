import Foundation
import SwiftUI

/// Drives the live `ChatView` for one resumed Claude session.
///
/// Responsibilities:
///  - load the JSONL transcript so the user sees the full backlog before
///    the live wire goes hot (TranscriptParser is shared with the read-only
///    Replay view; reusing it keeps rendering consistent)
///  - own a `ClaudeAgent` actor and pump its events into `[Turn]`
///  - expose status (idle / starting / streaming / error) for the UI
///  - serialise every UI mutation onto the main actor so SwiftUI sees a
///    clean snapshot per @Observable update
@MainActor
@Observable
final class ChatViewModel {

    // MARK: - Public state (read by ChatView)

    enum Status: Equatable {
        case idle
        case starting
        case ready
        case sending
        case error(String)
    }

    /// Project + session metadata for the header.
    let sessionPath: String
    let projectPath: String

    /// Existing turns from the JSONL plus any new ones from the live agent.
    var turns: [Turn] = []
    /// Set once the SDK reports an `init` system message.
    private(set) var sessionId: String = ""
    /// Last `result` event's reported cost (USD, this turn). UI shows a chip.
    private(set) var lastTurnCostUsd: Double = 0
    /// Cumulative cost across this app session (resets when chat closes).
    private(set) var cumulativeCostUsd: Double = 0
    private(set) var status: Status = .idle

    /// Permission mode chosen by the user. Changing this respawns the agent.
    var permissionMode: String = "default"
    /// Verbose toggle — passes `--partial-messages` to the sidecar.
    var verbose: Bool = false
    /// Tool allow-list (comma-separated). `nil` = SDK default.
    var allowedTools: String? = nil

    /// User-typed message in the input bar.
    var inputDraft: String = ""

    // MARK: - Private

    private let agent = ClaudeAgent()
    private var streamTask: Task<Void, Never>?

    // MARK: - Init

    init(sessionPath: String, projectPath: String) {
        self.sessionPath = sessionPath
        self.projectPath = projectPath
    }

    // Lifecycle cleanup is handled by `cancel()` from `ChatView.onDisappear`.
    // We deliberately don't try to call `agent.stop()` from `deinit` — the
    // actor isolation of `streamTask`/`agent` makes that ill-formed under
    // `SWIFT_STRICT_CONCURRENCY: complete`, and `onDisappear` always fires
    // before the view's state is torn down anyway.

    // MARK: - Lifecycle

    /// Load the existing JSONL into `turns`, then start the live agent.
    func start() async {
        guard status == .idle else { return }
        status = .starting

        // Seed the UI with what's already on disk so the user sees a full
        // backlog before the first live event lands.
        let existing = TranscriptParser.parseTranscript(filePath: sessionPath)
        turns = existing

        do {
            let opts = ClaudeAgent.StartOptions(
                sessionPath: sessionPath,
                workingDirectory: URL(fileURLWithPath: projectPath),
                permissionMode: permissionMode,
                allowedTools: allowedTools,
                includePartialMessages: verbose,
                skeleton: false
            )
            let stream = try await agent.start(options: opts)
            status = .ready
            streamTask = Task { [weak self] in await self?.consume(stream) }
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    /// Send the current `inputDraft` to the agent (clears the field on success).
    func send() async {
        let text = inputDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, status == .ready || status == .sending else { return }
        do {
            try await agent.send(text)
            // Optimistically append a user turn so the UI feels instant; the
            // SDK will echo it back as `userMessage` and we'll reconcile.
            appendUserTurn(text: text, optimistic: true)
            inputDraft = ""
            status = .sending
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    /// Cancel the in-flight turn (Esc).
    func cancel() async {
        await agent.stop()
        status = .idle
    }

    /// Switch permission mode mid-conversation. Respawns the agent with
    /// the new flag (the SDK applies it at session start).
    func changeMode(_ newMode: String) async {
        guard newMode != permissionMode else { return }
        permissionMode = newMode
        await restart()
    }

    /// Toggle verbose / partial messages. Also respawn-required.
    func setVerbose(_ on: Bool) async {
        guard on != verbose else { return }
        verbose = on
        await restart()
    }

    /// Tear down the current agent and start a fresh one with the
    /// current mode/verbose/tool settings.
    private func restart() async {
        streamTask?.cancel()
        await agent.stop()
        status = .idle
        await start()
    }

    // MARK: - Event folding

    /// Drains the sidecar event stream into `turns`.
    private func consume(_ stream: AsyncThrowingStream<StreamEvent, Error>) async {
        do {
            for try await event in stream {
                handle(event)
            }
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    private func handle(_ event: StreamEvent) {
        switch event {
        case .ready:
            status = .ready
        case .agentMessage(let msg):
            apply(msg)
        case .echo:
            break  // skeleton mode only
        case .error(let m):
            status = .error(m)
        case .exit:
            status = .idle
        case .unknown:
            break
        }
    }

    private func apply(_ msg: AgentMessage) {
        switch msg {
        case .systemInit(let sid, _, _):
            sessionId = sid
            status = .ready

        case .userMessage(let text, let toolResults, _):
            // The SDK echoes user messages we sent; if the last optimistic
            // turn matches, mark it confirmed instead of duplicating.
            if let last = turns.last, last.userText == text, last.blocks.isEmpty {
                // already there from optimistic insert
            } else if !text.isEmpty {
                appendUserTurn(text: text, optimistic: false)
            }
            // Tool-results land back as user messages — fold them under
            // the matching tool_use block on the most recent turn.
            for result in toolResults {
                applyToolResult(result)
            }

        case .assistantMessage(let blocks, _):
            _ = ensureCurrentTurn()
            replaceCurrentTurnBlocks(blocks)

        case .streamDelta:
            // Verbose mode: ignored in fold; surfaced separately via
            // the verbose panel in step 10.
            break

        case .result(_, _, let cost, _):
            lastTurnCostUsd = cost
            cumulativeCostUsd += cost
            status = .ready

        case .other:
            break
        }
    }

    private func appendUserTurn(text: String, optimistic: Bool) {
        let turn = Turn(
            id: UUID(),
            index: turns.count,
            userText: text,
            blocks: [],
            timestamp: ISO8601DateFormatter().string(from: Date()),
            systemEvents: optimistic ? ["pending"] : nil
        )
        turns.append(turn)
    }

    /// Append assistant blocks to the most recent user turn (creating a
    /// placeholder if none exists, e.g. when claude speaks first).
    private func ensureCurrentTurn() -> Turn {
        if let last = turns.last { return last }
        let placeholder = Turn(
            id: UUID(),
            index: 0,
            userText: "",
            blocks: [],
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
        turns.append(placeholder)
        return placeholder
    }

    /// Replace the last turn's assistant blocks with `blocks` (the SDK
    /// emits one fully-formed assistant message per turn; partials are
    /// in `streamDelta`, which we ignore in the fold today).
    private func replaceCurrentTurnBlocks(_ blocks: [AssistantContentBlock]) {
        guard !turns.isEmpty else { return }
        var last = turns[turns.count - 1]
        last.blocks = blocks.map(toAssistantBlock)
        last.systemEvents = nil // confirm no longer pending
        turns[turns.count - 1] = last
    }

    private func toAssistantBlock(_ b: AssistantContentBlock) -> AssistantBlock {
        switch b {
        case .text(let t):
            return AssistantBlock(id: UUID(), kind: .text, text: t, toolCall: nil, timestamp: nil)
        case .thinking(let t):
            return AssistantBlock(id: UUID(), kind: .thinking, text: t, toolCall: nil, timestamp: nil)
        case .toolUse(let id, let name, let inputJson):
            let input = parseInputDict(inputJson)
            return AssistantBlock(
                id: UUID(),
                kind: .toolUse,
                text: "",
                toolCall: ToolCall(toolUseId: id, name: name, input: input, result: nil, isError: false),
                timestamp: nil
            )
        }
    }

    private func applyToolResult(_ result: ToolResult) {
        // Walk the most recent turn's blocks and fill the matching tool_use.
        guard !turns.isEmpty else { return }
        var turn = turns[turns.count - 1]
        for i in 0..<turn.blocks.count {
            if turn.blocks[i].kind == .toolUse,
               turn.blocks[i].toolCall?.toolUseId == result.toolUseId {
                turn.blocks[i].toolCall?.result = result.content
                turn.blocks[i].toolCall?.isError = result.isError
            }
        }
        turns[turns.count - 1] = turn
    }

    private func parseInputDict(_ json: String) -> [String: AnyCodable] {
        guard let data = json.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        var out: [String: AnyCodable] = [:]
        for (k, v) in raw { out[k] = AnyCodable(v) }
        return out
    }
}
