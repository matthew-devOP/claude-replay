import Foundation

/// Computes the per-session metadata the Sessions table renders alongside
/// the file-system info already in `SessionEntry`:
///   • `preview` — first user message, ~140 chars
///   • `userPreviews` — first few user messages for the hover popover
///   • `turnCount` — full count of user turns
///   • `durationSeconds` — `last - first` turn timestamp
///
/// Implementation: delegates to `TranscriptParser.parseTranscript` so we
/// pick up the same XML-tag stripping and Cursor/Codex format detection
/// the rest of the app already uses. That makes meta computation correct
/// at the cost of being O(N) over the JSONL — fine for on-demand loading
/// from a `LazyVStack`'s `.onAppear`, since only visible rows pay.
enum SessionMetaService {

    /// Synchronous meta for one session. Suitable for calling from a
    /// detached `Task` per row (each parse is independent).
    static func meta(for path: String) -> SessionEntry.MetaPatch {
        let turns = TranscriptParser.parseTranscript(filePath: path)
        let userTexts: [String] = turns.compactMap { turn in
            let cleaned = TranscriptParser
                .cleanSystemTags(turn.userText)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : cleaned
        }
        let preview = userTexts.first.map { String($0.prefix(140)) } ?? ""
        let userPreviews = Array(userTexts.prefix(5))

        let duration: TimeInterval?
        let iso = ISO8601DateFormatter()
        if let firstTS = turns.first?.timestamp,
           let lastTS  = turns.last?.timestamp,
           let first   = iso.date(from: firstTS),
           let last    = iso.date(from: lastTS),
           last > first {
            duration = last.timeIntervalSince(first)
        } else {
            duration = nil
        }

        return SessionEntry.MetaPatch(
            preview: preview,
            userPreviews: userPreviews,
            turnCount: turns.count,
            durationSeconds: duration
        )
    }
}

extension SessionEntry {
    /// Subset of fields populated by `SessionMetaService.meta(for:)`.
    /// Kept separate from the value type so partial enrichment doesn't
    /// require constructing a brand-new `SessionEntry` each time.
    struct MetaPatch: Sendable {
        let preview: String
        let userPreviews: [String]
        let turnCount: Int
        let durationSeconds: TimeInterval?
    }

    mutating func apply(_ patch: MetaPatch) {
        self.preview = patch.preview
        self.userPreviews = patch.userPreviews
        self.turnCount = patch.turnCount
        self.durationSeconds = patch.durationSeconds
    }
}

// `formattedDuration()` already exists on TimeInterval in
// Extensions/Date+Formatting.swift — reuse it here.
