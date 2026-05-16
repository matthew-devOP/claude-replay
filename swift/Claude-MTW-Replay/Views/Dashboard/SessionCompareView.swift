import SwiftUI

/// Side-by-side comparison sheet for two sessions selected from the
/// Sessions table. Each pane shows the same TranscriptTurnView the
/// Replay/Transcript tabs use, so styling is consistent.
///
/// Turns are aligned via `TurnDiffer.diff(left:right:)` (LCS over
/// word-level Jaccard similarity on `userText`) and color-coded:
///   * identical → subtle gray
///   * modified  → yellow
///   * added     → green (right pane only; left shows a placeholder)
///   * removed   → red   (left pane only; right shows a placeholder)
///
/// To keep the algorithm responsive, diff is only computed when the
/// combined turn count stays under `Self.diffTurnLimit`; otherwise the
/// sheet falls back to plain side-by-side display with a warning banner.
struct SessionCompareView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    let leftPath: String
    let rightPath: String

    /// Combined-turn ceiling above which we skip the diff computation.
    /// Picked to keep the O(n*m) Jaccard precompute well under ~40k cells.
    private static let diffTurnLimit = 200

    @State private var leftTurns: [Turn] = []
    @State private var rightTurns: [Turn] = []
    @State private var diffSummary: SessionDiffSummary = .empty
    @State private var diffTooLarge = false
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if diffTooLarge {
                warningBanner
                Divider()
            }
            HSplitView {
                if loaded && !diffTooLarge {
                    pane(title: leftPath, side: .left)
                    pane(title: rightPath, side: .right)
                } else {
                    rawPane(title: leftPath, turns: leftTurns)
                    rawPane(title: rightPath, turns: rightTurns)
                }
            }
        }
        .task {
            leftTurns  = TranscriptParser.parseTranscript(filePath: leftPath)
            rightTurns = TranscriptParser.parseTranscript(filePath: rightPath)
            if leftTurns.count + rightTurns.count > Self.diffTurnLimit {
                diffTooLarge = true
                diffSummary = .empty
            } else {
                diffSummary = TurnDiffer.diff(left: leftTurns, right: rightTurns)
            }
            loaded = true
        }
    }

    // MARK: - Header / banner

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Compare sessions")
                    .font(.headline)
                if loaded && !diffTooLarge {
                    Text(summaryLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(12)
    }

    private var summaryLine: String {
        let s = diffSummary
        return "\(s.identical) identical · \(s.modified) modified · \(s.added) added · \(s.removed) removed"
    }

    private var warningBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Sessions too large for diff; showing side-by-side only.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.08))
    }

    // MARK: - Panes

    private enum Side { case left, right }

    private func pane(title: String, side: Side) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            paneTitle(title)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(diffSummary.entries) { entry in
                        diffRow(entry: entry, side: side)
                    }
                }
                .padding(.vertical, 12)
            }
        }
        .frame(minWidth: 360)
        .background(appState.theme.bg)
    }

    /// Fallback pane used when diff is unavailable (sessions too large
    /// or content not yet loaded). Renders each turn without alignment.
    private func rawPane(title: String, turns: [Turn]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            paneTitle(title)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(turns) { turn in
                        TranscriptTurnView(turn: turn)
                            .padding(.horizontal, 12)
                    }
                }
                .padding(.vertical, 12)
            }
        }
        .frame(minWidth: 360)
        .background(appState.theme.bg)
    }

    private func paneTitle(_ title: String) -> some View {
        Text(URL(fileURLWithPath: title).lastPathComponent
            .replacingOccurrences(of: ".jsonl", with: ""))
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(appState.theme.accent)
            .padding(8)
    }

    @ViewBuilder
    private func diffRow(entry: TurnDiffEntry, side: Side) -> some View {
        let turn = (side == .left) ? entry.leftTurn : entry.rightTurn
        if let turn {
            TranscriptTurnView(turn: turn)
                .padding(8)
                .background(background(for: entry.kind, side: side))
                .cornerRadius(6)
                .padding(.horizontal, 8)
        } else {
            // Placeholder so the opposite-side row stays vertically aligned.
            placeholder(for: entry.kind, side: side)
                .padding(.horizontal, 8)
        }
    }

    private func background(for kind: TurnDiffKind, side: Side) -> Color {
        switch kind {
        case .identical: return Color.gray.opacity(0.05)
        case .modified:  return Color.yellow.opacity(0.15)
        case .added:     // only ever rendered on the right
            return Color.green.opacity(0.15)
        case .removed:   // only ever rendered on the left
            return Color.red.opacity(0.15)
        }
    }

    private func placeholder(for kind: TurnDiffKind, side: Side) -> some View {
        // Tint the empty slot to match its sibling so the side-by-side
        // gutters stay readable even with no content.
        let tint: Color = {
            switch kind {
            case .added:   return Color.green.opacity(0.06)
            case .removed: return Color.red.opacity(0.06)
            default:       return Color.gray.opacity(0.04)
            }
        }()
        let label: String = {
            switch kind {
            case .added where side == .left:   return "— added in right —"
            case .removed where side == .right: return "— removed from left —"
            default: return " "
            }
        }()
        return HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 36)
        .padding(8)
        .background(tint)
        .cornerRadius(6)
    }
}
