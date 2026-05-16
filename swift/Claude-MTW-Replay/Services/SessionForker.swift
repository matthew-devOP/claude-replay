import Foundation

/// G2 — Conversation forking / branching.
///
/// `SessionForker.fork` duplicates a Claude JSONL session file on disk,
/// truncating it at the N-th user turn so a new conversation can resume
/// from that point without disturbing the original transcript.
///
/// Implementation notes (MVP):
///  - Real `~/.claude/projects/*.jsonl` files contain non-conversational
///    bookkeeping records (`permission-mode`, `file-history-snapshot`,
///    summary entries, etc.) interleaved with `"type":"user"` and
///    `"type":"assistant"` messages. We preserve every prelude line up to
///    the cut point so the new session keeps its session-level metadata.
///  - The "turn index" follows the UI's notion of a *user* turn:
///    `turnIndex == 0` keeps everything before the first user message,
///    `turnIndex == 1` keeps the first user message (and any prelude or
///    assistant reply that came with it), and so on. We cut *before* the
///    (turnIndex+1)-th user line so the branch can immediately accept the
///    next user prompt.
///  - We tolerate empty/missing trailing newlines and avoid rewriting the
///    bytes we keep — just a prefix-write, which is fast and matches
///    how Claude appends to JSONL.
enum SessionForker {

    enum ForkError: Error, LocalizedError {
        case sourceMissing(String)
        case writeFailed(String, underlying: Error)

        var errorDescription: String? {
            switch self {
            case .sourceMissing(let p):
                return "Source session file not found: \(p)"
            case .writeFailed(let p, let err):
                return "Failed to write branch file at \(p): \(err.localizedDescription)"
            }
        }
    }

    /// Duplicate `sourcePath` as a sibling `*-branch-<timestamp>.jsonl`,
    /// truncated at the `turnIndex`-th user turn. Returns the new file URL.
    ///
    /// - Parameter turnIndex: The 0-based index of the user turn we want
    ///   the branch to end *just before*. `0` keeps any prelude metadata
    ///   but drops every user/assistant exchange; `N` keeps the first N
    ///   user prompts (and everything between them) but drops the rest.
    /// - Parameter label: Optional human-readable label; currently unused
    ///   by the on-disk format itself (it's stored in SwiftData via
    ///   `DataStore.forkSession`), but accepted here so callers can pass
    ///   it through one entry point.
    @discardableResult
    static func fork(
        sourcePath: String,
        atTurnIndex turnIndex: Int,
        label: String? = nil
    ) throws -> URL {
        _ = label  // accepted for API symmetry; persisted by the DataStore layer

        let sourceURL = URL(fileURLWithPath: sourcePath)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw ForkError.sourceMissing(sourcePath)
        }

        let parentDir = sourceURL.deletingLastPathComponent()
        let sourceStem = sourceURL.deletingPathExtension().lastPathComponent
        let timestamp = ISO8601DateFormatter().string(from: .now)
            .replacingOccurrences(of: ":", with: "-")
        let newName = "\(sourceStem)-branch-\(timestamp).jsonl"
        let newURL = parentDir.appendingPathComponent(newName)

        let content = try String(contentsOf: sourceURL, encoding: .utf8)
        // Keep empty trailing line so we round-trip a clean newline-
        // terminated file.
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)

        // Naive but format-correct truncation: scan for `"type":"user"`
        // records, and cut *before* the (turnIndex+1)-th match. Falling
        // back to `"role":"user"` keeps us compatible with the older
        // shape used by some sidecar fixtures.
        var userCount = 0
        var truncateIdx: Int = lines.count
        for (i, rawLine) in lines.enumerated() {
            let line = String(rawLine)
            guard line.contains("\"type\":\"user\"") || line.contains("\"role\":\"user\"") else {
                continue
            }
            if userCount >= turnIndex {
                truncateIdx = i
                break
            }
            userCount += 1
        }

        var truncated = lines.prefix(truncateIdx).joined(separator: "\n")
        // Preserve the trailing newline convention so Claude can append
        // new records cleanly when the branch is resumed.
        if !truncated.isEmpty, !truncated.hasSuffix("\n") {
            truncated += "\n"
        }
        do {
            try truncated.write(to: newURL, atomically: true, encoding: .utf8)
        } catch {
            throw ForkError.writeFailed(newURL.path, underlying: error)
        }
        return newURL
    }
}
