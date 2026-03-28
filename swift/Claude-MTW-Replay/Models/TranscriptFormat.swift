import Foundation

/// The source format of a JSONL transcript file.
enum TranscriptFormat: String, Codable, Sendable {
    case claudeCode = "claude-code"
    case cursor
    case codex
    case unknown

    var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .cursor: return "Cursor"
        case .codex: return "Codex"
        case .unknown: return "Unknown"
        }
    }
}
