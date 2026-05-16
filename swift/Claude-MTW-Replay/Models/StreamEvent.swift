import Foundation

/// A single line read from the Node sidecar's stdout, decoded into a typed
/// case. The sidecar emits a JSON object per line and tags each with a
/// `type` discriminator. We model both the plumbing events (ready / echo
/// / error / exit) and the in-flight agent events from
/// `@anthropic-ai/claude-agent-sdk`.
///
/// Keep this enum small and forgiving: unknown event types decode to
/// `.unknown(raw:)` so the wire format can evolve without breaking the
/// app.
enum StreamEvent: Equatable, Sendable {
    /// Sidecar's first frame: wire-protocol handshake. Sent before any
    /// other event so the Swift side can validate version compatibility
    /// before sending commands.
    case hello(protocolVersion: String, version: String?, pid: Int?)
    /// Periodic liveness ping. The watchdog kills the sidecar if these
    /// stop arriving.
    case heartbeat(timestamp: Date)
    /// Structured diagnostic log from the sidecar. Replaces stderr writes.
    case log(level: String, msg: String, meta: [String: String]?)
    /// Sidecar booted; payload includes the mode (`"skeleton"` | `"agent"`).
    case ready(mode: String)
    /// Skeleton-mode echo of a user message. Used for plumbing tests.
    case echo(input: String)
    /// Real agent event from the SDK, fully decoded into a typed sub-case.
    case agentMessage(AgentMessage)
    /// Soft error from the sidecar (printed to stderr by the Agent SDK
    /// or thrown by sidecar.js). Doesn't terminate the connection.
    case error(message: String)
    /// Sidecar process is shutting down; `code` mirrors the process exit code.
    case exit(code: Int)
    /// Catch-all so unknown events never abort the read loop.
    case unknown(raw: String)
}

/// Decoded payload of one `{type:"agent_event", event:<SDKMessage>}` line.
///
/// Mirrors only what the Chats UI needs from `SDKMessage` — full block
/// content for user/assistant messages, plus the result envelope for
/// usage/cost. Stream-event deltas (partial messages) are forwarded as
/// `.streamDelta(raw:)` so the UI can opt into surfacing them later
/// without us hard-coding the BetaRawMessageStreamEvent shape now.
enum AgentMessage: Equatable, Sendable {
    /// `{type:"system", subtype:"init", session_id, model, cwd, ...}`.
    /// Emitted once at the start. We surface only the fields the UI uses.
    case systemInit(sessionId: String, model: String?, cwd: String?)

    /// `{type:"user", message:{role:"user", content:...}, session_id}`.
    /// `content` is either a single string or an array of blocks; we
    /// flatten any text segments and detect tool_result blocks so the UI
    /// can fold them under the matching tool_use.
    case userMessage(text: String, toolResults: [ToolResult], sessionId: String)

    /// `{type:"assistant", message:{...content blocks...}, session_id}`.
    case assistantMessage(blocks: [AssistantContentBlock], sessionId: String)

    /// Streamed deltas from `--include-partial-messages`. Step 10 wires
    /// them into the UI via the verbose toggle; until then we just keep
    /// the raw JSON so consumers can ignore them.
    case streamDelta(raw: String)

    /// `{type:"result", subtype, duration_ms, num_turns, total_cost_usd, ...}`.
    case result(success: Bool, durationMs: Int, costUsd: Double, numTurns: Int, usage: TokenUsage?)

    /// Anything else — `compact_boundary`, `status`, `hook_response`, etc.
    /// We keep raw JSON so the UI can choose to display them as system events.
    case other(type: String, raw: String)
}

/// Token usage reported in a `result` event. Mirrors the Anthropic API
/// `usage` object — input/output tokens plus optional cache counters.
struct TokenUsage: Codable, Equatable, Sendable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}

/// One block inside `assistantMessage.blocks` — a slim version of the
/// Anthropic API content block.
enum AssistantContentBlock: Equatable, Sendable {
    case text(String)
    case thinking(String)
    case toolUse(id: String, name: String, input: String) // input as JSON string
}

struct ToolResult: Equatable, Sendable {
    let toolUseId: String
    let content: String
    let isError: Bool
}

extension StreamEvent {
    /// Decode one line from the sidecar's stdout. Returns `.unknown` if the
    /// line isn't valid JSON or has an unrecognized `type`. Whitespace lines
    /// return nil so callers can simply `if let event = …` and skip them.
    static func decode(line: String) -> StreamEvent? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        guard let data = trimmed.data(using: .utf8) else { return .unknown(raw: trimmed) }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .unknown(raw: trimmed)
        }
        let type = object["type"] as? String ?? ""
        switch type {
        case "hello":
            let protoStr: String
            if let s = object["protocol"] as? String {
                protoStr = s
            } else if let n = object["protocol"] as? Int {
                protoStr = String(n)
            } else {
                protoStr = ""
            }
            return .hello(
                protocolVersion: protoStr,
                version: object["version"] as? String,
                pid: object["pid"] as? Int
            )
        case "heartbeat":
            // `ts` is JS `Date.now()` — milliseconds since 1970.
            let ms = (object["ts"] as? Double) ?? Double(object["ts"] as? Int ?? 0)
            let date = Date(timeIntervalSince1970: ms / 1000.0)
            return .heartbeat(timestamp: date)
        case "log":
            let level = object["level"] as? String ?? "info"
            let msg = object["msg"] as? String ?? ""
            var meta: [String: String]? = nil
            if let m = object["meta"] as? [String: Any] {
                var flat: [String: String] = [:]
                for (k, v) in m { flat[k] = String(describing: v) }
                meta = flat
            }
            return .log(level: level, msg: msg, meta: meta)
        case "ready":
            return .ready(mode: object["mode"] as? String ?? "")
        case "echo":
            return .echo(input: object["input"] as? String ?? "")
        case "agent_event":
            guard let inner = object["event"] as? [String: Any] else {
                return .unknown(raw: trimmed)
            }
            return .agentMessage(AgentMessage.decode(inner))
        case "error":
            return .error(message: object["message"] as? String ?? "")
        case "exit":
            return .exit(code: object["code"] as? Int ?? 0)
        default:
            return .unknown(raw: trimmed)
        }
    }
}

extension AgentMessage {
    /// Decode an SDK message JSON object into the slim Swift model used
    /// by the UI. Unknown shapes fall back to `.other(...)` rather than
    /// erroring — the SDK frequently adds non-breaking fields and we
    /// don't want a single new event type to crash the chat.
    static func decode(_ object: [String: Any]) -> AgentMessage {
        let type = object["type"] as? String ?? ""
        let sessionId = object["session_id"] as? String ?? ""

        switch type {
        case "system":
            // Subtype "init" carries model/cwd. Other subtypes (e.g. compact)
            // are surfaced via `.other`.
            if (object["subtype"] as? String) == "init" {
                return .systemInit(
                    sessionId: sessionId,
                    model: object["model"] as? String,
                    cwd: object["cwd"] as? String
                )
            }
            return .other(type: type, raw: rawJson(object))

        case "user":
            return decodeUser(object, sessionId: sessionId)

        case "assistant":
            return decodeAssistant(object, sessionId: sessionId)

        case "stream_event":
            return .streamDelta(raw: rawJson(object))

        case "result":
            let isError = object["is_error"] as? Bool ?? false
            return .result(
                success: !isError && (object["subtype"] as? String) == "success",
                durationMs: object["duration_ms"] as? Int ?? 0,
                costUsd: object["total_cost_usd"] as? Double ?? 0,
                numTurns: object["num_turns"] as? Int ?? 0,
                usage: decodeUsage(object["usage"])
            )

        default:
            return .other(type: type, raw: rawJson(object))
        }
    }

    // MARK: - Per-type decoders

    /// `user` messages can be:
    ///  - real user prompts with text content
    ///  - tool_result echoes (synthesized after a tool_use)
    /// We split text content out into `text` and tool_result blocks
    /// into `toolResults`.
    private static func decodeUser(_ object: [String: Any], sessionId: String) -> AgentMessage {
        let message = object["message"] as? [String: Any] ?? [:]
        var text = ""
        var toolResults: [ToolResult] = []

        switch message["content"] {
        case let s as String:
            text = s
        case let blocks as [[String: Any]]:
            for block in blocks {
                let blockType = block["type"] as? String ?? ""
                switch blockType {
                case "text":
                    if let t = block["text"] as? String { text += t }
                case "tool_result":
                    let id = block["tool_use_id"] as? String ?? ""
                    let isError = block["is_error"] as? Bool ?? false
                    let content = stringifyToolResultContent(block["content"])
                    toolResults.append(ToolResult(toolUseId: id, content: content, isError: isError))
                default:
                    break
                }
            }
        default:
            break
        }
        return .userMessage(text: text, toolResults: toolResults, sessionId: sessionId)
    }

    private static func decodeAssistant(_ object: [String: Any], sessionId: String) -> AgentMessage {
        let message = object["message"] as? [String: Any] ?? [:]
        let rawBlocks = message["content"] as? [[String: Any]] ?? []
        var blocks: [AssistantContentBlock] = []
        for block in rawBlocks {
            switch block["type"] as? String {
            case "text":
                if let t = block["text"] as? String, !t.isEmpty {
                    blocks.append(.text(t))
                }
            case "thinking":
                let t = block["thinking"] as? String ?? block["text"] as? String ?? ""
                if !t.isEmpty { blocks.append(.thinking(t)) }
            case "tool_use":
                let id = block["id"] as? String ?? ""
                let name = block["name"] as? String ?? ""
                let inputJson = (block["input"]).map { rawJson($0) } ?? "{}"
                blocks.append(.toolUse(id: id, name: name, input: inputJson))
            default:
                break
            }
        }
        return .assistantMessage(blocks: blocks, sessionId: sessionId)
    }

    /// `tool_result.content` may be a string or an array of blocks. Flatten
    /// text-blocks; non-text blocks are skipped (rare for tool results).
    private static func stringifyToolResultContent(_ value: Any?) -> String {
        switch value {
        case let s as String:
            return s
        case let blocks as [[String: Any]]:
            return blocks.compactMap { $0["text"] as? String }.joined()
        case let dict as [String: Any]:
            return rawJson(dict)
        default:
            return ""
        }
    }

    /// Best-effort decode of the `usage` field on a result event. Returns
    /// nil when the payload is missing or doesn't carry input/output counts.
    private static func decodeUsage(_ value: Any?) -> TokenUsage? {
        guard let dict = value as? [String: Any] else { return nil }
        let input = dict["input_tokens"] as? Int ?? 0
        let output = dict["output_tokens"] as? Int ?? 0
        // If both are zero and no cache numbers are present, treat as absent.
        let cacheCreate = dict["cache_creation_input_tokens"] as? Int
        let cacheRead = dict["cache_read_input_tokens"] as? Int
        if input == 0 && output == 0 && cacheCreate == nil && cacheRead == nil {
            return nil
        }
        return TokenUsage(
            inputTokens: input,
            outputTokens: output,
            cacheCreationInputTokens: cacheCreate,
            cacheReadInputTokens: cacheRead
        )
    }

    private static func rawJson(_ value: Any) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: value),
           let s = String(data: data, encoding: .utf8) {
            return s
        }
        return ""
    }
}
