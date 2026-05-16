import SwiftUI

/// Ephemeral replay sheet for a multi-session chain produced by
/// `TranscriptParser.parseAndChain(filePaths:)`. The chained turns are
/// passed in directly (already re-indexed) and rendered with the same
/// `ReplayTurnView` used in the main Replay tab. Nothing is persisted —
/// closing the sheet discards the chain.
///
/// P1.2 — Session chaining (docs/IMPROVEMENTS_SWIFT.md lines 178-181).
struct ChainedReplaySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let turns: [Turn]
    let sessionCount: Int

    @State private var showThinking: Bool = true
    @State private var showToolCalls: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if turns.isEmpty {
                EmptyStateView(
                    icon: "link",
                    title: "No turns",
                    subtitle: "The chained sessions did not produce any turns."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(turns.enumerated()), id: \.offset) { index, turn in
                            ReplayTurnView(
                                turn: turn,
                                turnNumber: index + 1,
                                revealedBlocks: turn.blocks.count,
                                showThinking: showThinking,
                                showToolCalls: showToolCalls
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "link")
                .foregroundStyle(appState.theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Chained Replay")
                    .font(.headline)
                Text("\(sessionCount) session\(sessionCount == 1 ? "" : "s") · \(turns.count) turns (ephemeral)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Thinking", isOn: $showThinking)
                .toggleStyle(.switch)
                .controlSize(.small)
            Toggle("Tools", isOn: $showToolCalls)
                .toggleStyle(.switch)
                .controlSize(.small)
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(12)
    }
}
