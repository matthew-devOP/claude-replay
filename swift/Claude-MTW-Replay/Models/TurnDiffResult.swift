import Foundation

/// Classification of a single diff entry produced by `TurnDiffer`.
enum TurnDiffKind: Sendable {
    case identical
    case modified
    case added
    case removed
}

/// A single row of a session-vs-session diff.
///
/// - `leftTurn` is `nil` when the entry represents a turn that was only
///   present in the right session (`.added`).
/// - `rightTurn` is `nil` when the entry represents a turn that was only
///   present in the left session (`.removed`).
/// - For `.identical` / `.modified`, both sides are populated.
struct TurnDiffEntry: Identifiable, Sendable {
    let id = UUID()
    let kind: TurnDiffKind
    let leftTurn: Turn?
    let rightTurn: Turn?
    /// Word-level Jaccard similarity between left and right userText. Range 0...1.
    /// For `.added` / `.removed` entries this is `0`.
    let similarity: Double
}

/// Aggregate result of comparing two sessions.
struct SessionDiffSummary: Sendable {
    let identical: Int
    let modified: Int
    let added: Int
    let removed: Int
    let entries: [TurnDiffEntry]

    static let empty = SessionDiffSummary(
        identical: 0,
        modified: 0,
        added: 0,
        removed: 0,
        entries: []
    )
}
