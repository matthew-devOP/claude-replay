import SwiftUI

/// Side-by-side comparison sheet for two sessions selected from the
/// Sessions table. Each pane shows the same TranscriptTurnView the
/// Replay/Transcript tabs use, so styling is consistent.
///
/// v0.8.1-swift ships side-by-side display without diff highlighting;
/// semantic per-turn diffing is queued for a follow-up.
struct SessionCompareView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    let leftPath: String
    let rightPath: String

    @State private var leftTurns: [Turn] = []
    @State private var rightTurns: [Turn] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Compare sessions")
                    .font(.headline)
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(12)
            Divider()
            HSplitView {
                pane(title: leftPath, turns: leftTurns)
                pane(title: rightPath, turns: rightTurns)
            }
        }
        .task {
            leftTurns  = TranscriptParser.parseTranscript(filePath: leftPath)
            rightTurns = TranscriptParser.parseTranscript(filePath: rightPath)
        }
    }

    private func pane(title: String, turns: [Turn]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(URL(fileURLWithPath: title).lastPathComponent
                .replacingOccurrences(of: ".jsonl", with: ""))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(appState.theme.accent)
                .padding(8)
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
}
