import SwiftUI

/// G2 — Disclosure listing direct child branches forked from a given
/// chat session. Mounted by `ChatActiveListView` or similar surfaces
/// that already know which `sessionPath` is in focus.
///
/// Behaviour:
///  - The view collapses to nothing when the session has no branches,
///    so it stays out of the way for the common single-thread case.
///  - Each row jumps to the branch via `AppState.selectSession`, which
///    routes the UI to the Replay tab focused on the new JSONL.
struct ChatBranchListView: View {
    @Environment(AppState.self) private var appState
    let sessionPath: String
    @State private var branches: [ChatTranscriptEntity] = []

    var body: some View {
        Group {
            if !branches.isEmpty {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: DesignTokens.space4) {
                        ForEach(branches, id: \.sessionPath) { branch in
                            branchRow(branch)
                        }
                    }
                    .padding(.vertical, DesignTokens.space4)
                } label: {
                    HStack(spacing: DesignTokens.space6) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.caption)
                        Text("Branches")
                            .font(.caption.smallCaps())
                        Text("(\(branches.count))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, DesignTokens.space12)
                .padding(.vertical, DesignTokens.space6)
            } else {
                EmptyView()
            }
        }
        .task(id: sessionPath) {
            branches = DataStore.shared.getBranches(sessionPath: sessionPath)
        }
    }

    @ViewBuilder
    private func branchRow(_ branch: ChatTranscriptEntity) -> some View {
        Button {
            appState.selectSession(branch.sessionPath)
        } label: {
            HStack(spacing: DesignTokens.space8) {
                VStack(alignment: .leading, spacing: DesignTokens.space2) {
                    Text(displayLabel(for: branch))
                        .font(.caption)
                        .lineLimit(1)
                    Text(branch.lastUpdated.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Prefer the explicit `branchLabel` (set by `forkSession`); fall back
    /// to `displayName` and finally to the file's last path component so
    /// rows never render blank even on partial data.
    private func displayLabel(for branch: ChatTranscriptEntity) -> String {
        if let label = branch.branchLabel, !label.isEmpty { return label }
        if let name = branch.displayName, !name.isEmpty { return name }
        return URL(fileURLWithPath: branch.sessionPath).lastPathComponent
    }
}
