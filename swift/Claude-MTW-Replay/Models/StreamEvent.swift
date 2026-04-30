import Foundation

/// A single line read from the Node sidecar's stdout, decoded into a typed
/// case. The sidecar emits a JSON object per line and tags each with a
/// `type` discriminator. We model both the plumbing events (ready / echo
/// / error / exit) and the in-flight agent events (which step 5 fills in
/// once `@anthropic-ai/claude-agent-sdk` is wired up).
///
/// Keep this enum small and forgiving: unknown event types decode to
/// `.unknown(raw:)` so the wire format can evolve without breaking the
/// app.
enum StreamEvent: Equatable, Sendable {
    /// Sidecar booted; payload includes the mode (`"skeleton"` | `"agent"`).
    case ready(mode: String)
    /// Skeleton-mode echo of a user message. Used for plumbing tests.
    case echo(input: String)
    /// Real agent event from the Claude Agent SDK. Step 6 will decode the
    /// inner payload into typed sub-cases (assistant_delta, tool_use, …);
    /// for step 4 we keep it as raw JSON so the actor compiles end-to-end.
    case agentEvent(json: String)
    /// Soft error from the sidecar (printed to stderr by the Agent SDK
    /// or thrown by sidecar.js). Doesn't terminate the connection.
    case error(message: String)
    /// Sidecar process is shutting down; `code` mirrors the process exit code.
    case exit(code: Int)
    /// Catch-all so unknown events never abort the read loop.
    case unknown(raw: String)
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
        case "ready":
            return .ready(mode: object["mode"] as? String ?? "")
        case "echo":
            return .echo(input: object["input"] as? String ?? "")
        case "agent_event":
            // Re-serialize the inner event so step 6 can decode against
            // the SDK's schema with a single `JSONDecoder` pass.
            if let inner = object["event"],
               let innerData = try? JSONSerialization.data(withJSONObject: inner),
               let innerString = String(data: innerData, encoding: .utf8) {
                return .agentEvent(json: innerString)
            }
            return .unknown(raw: trimmed)
        case "error":
            return .error(message: object["message"] as? String ?? "")
        case "exit":
            return .exit(code: object["code"] as? Int ?? 0)
        default:
            return .unknown(raw: trimmed)
        }
    }
}
