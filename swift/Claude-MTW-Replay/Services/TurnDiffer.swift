import Foundation

/// Diffs two ordered arrays of `Turn` using an LCS-style alignment over
/// `userText` similarity.
///
/// Matching is done on word-level Jaccard similarity:
/// `|A ∩ B| / |A ∪ B|`. A pair is considered a "match" for LCS purposes
/// when similarity is strictly greater than `0.5`. Within matched pairs:
///   * similarity == 1.0  → `.identical`
///   * 0.5 < similarity < 1.0  → `.modified`
/// Turns that fail to align are emitted as standalone `.removed` (left)
/// or `.added` (right) entries while preserving original ordering.
enum TurnDiffer {

    // MARK: - Public API

    static func diff(left: [Turn], right: [Turn]) -> SessionDiffSummary {
        if left.isEmpty && right.isEmpty {
            return .empty
        }

        let n = left.count
        let m = right.count

        // Precompute pairwise similarity once (n*m). At 200x200 = 40k cells,
        // each requiring a small set operation — well within budget.
        var sim = [[Double]](
            repeating: [Double](repeating: 0, count: m),
            count: n
        )
        let leftTokens = left.map { tokenSet($0.userText) }
        let rightTokens = right.map { tokenSet($0.userText) }
        for i in 0..<n {
            for j in 0..<m {
                sim[i][j] = jaccard(leftTokens[i], rightTokens[j])
            }
        }

        // LCS DP where score[i][j] = best total similarity of aligning
        // left[0..<i] with right[0..<j], only counting cells with
        // sim > 0.5 as a usable match.
        let matchThreshold = 0.5
        var score = [[Double]](
            repeating: [Double](repeating: 0, count: m + 1),
            count: n + 1
        )
        for i in 1...max(n, 1) where i <= n {
            for j in 1...max(m, 1) where j <= m {
                let s = sim[i - 1][j - 1]
                let diag = score[i - 1][j - 1] + (s > matchThreshold ? s : 0)
                let up = score[i - 1][j]
                let left = score[i][j - 1]
                score[i][j] = max(diag, max(up, left))
            }
        }

        // Backtrack to recover the alignment in reverse.
        var entries: [TurnDiffEntry] = []
        var i = n
        var j = m
        while i > 0 || j > 0 {
            if i > 0 && j > 0 {
                let s = sim[i - 1][j - 1]
                let diag = score[i - 1][j - 1] + (s > matchThreshold ? s : 0)
                if s > matchThreshold && score[i][j] == diag {
                    let kind: TurnDiffKind = (s >= 0.999) ? .identical : .modified
                    entries.append(
                        TurnDiffEntry(
                            kind: kind,
                            leftTurn: left[i - 1],
                            rightTurn: right[j - 1],
                            similarity: s
                        )
                    )
                    i -= 1
                    j -= 1
                    continue
                }
            }
            if i > 0 && (j == 0 || score[i - 1][j] >= score[i][j - 1]) {
                entries.append(
                    TurnDiffEntry(
                        kind: .removed,
                        leftTurn: left[i - 1],
                        rightTurn: nil,
                        similarity: 0
                    )
                )
                i -= 1
            } else {
                entries.append(
                    TurnDiffEntry(
                        kind: .added,
                        leftTurn: nil,
                        rightTurn: right[j - 1],
                        similarity: 0
                    )
                )
                j -= 1
            }
        }

        entries.reverse()

        var identical = 0
        var modified = 0
        var added = 0
        var removed = 0
        for e in entries {
            switch e.kind {
            case .identical: identical += 1
            case .modified:  modified  += 1
            case .added:     added     += 1
            case .removed:   removed   += 1
            }
        }

        return SessionDiffSummary(
            identical: identical,
            modified: modified,
            added: added,
            removed: removed,
            entries: entries
        )
    }

    // MARK: - Similarity helpers

    /// Word-level Jaccard similarity. Empty inputs are treated as identical
    /// (both 1.0) only when both are empty; an empty vs non-empty returns 0.
    private static func jaccard(_ a: Set<String>, _ b: Set<String>) -> Double {
        if a.isEmpty && b.isEmpty { return 1.0 }
        if a.isEmpty || b.isEmpty { return 0.0 }
        let intersection = a.intersection(b).count
        let union = a.union(b).count
        guard union > 0 else { return 0 }
        return Double(intersection) / Double(union)
    }

    /// Tokenise a string into a lowercase set of word-like tokens. Whitespace
    /// and most punctuation are stripped; tokens shorter than 2 chars are
    /// kept as long as they're alphanumeric (e.g. "i", "a", numbers).
    private static func tokenSet(_ s: String) -> Set<String> {
        var out: Set<String> = []
        var current = ""
        for ch in s.lowercased() {
            if ch.isLetter || ch.isNumber {
                current.append(ch)
            } else if !current.isEmpty {
                out.insert(current)
                current = ""
            }
        }
        if !current.isEmpty {
            out.insert(current)
        }
        return out
    }
}
