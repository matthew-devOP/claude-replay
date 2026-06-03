import SwiftUI

struct ProjectRowView: View {
    @Environment(AppState.self) private var appState
    let project: ProjectEntry
    /// When non-empty, the project path is rendered under the name as match
    /// context (mirrors the web sidebar's search behaviour).
    var searchText: String = ""

    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundStyle(appState.theme.accent)
            VStack(alignment: .leading, spacing: DesignTokens.space2) {
                Text(project.name).font(.headline).lineLimit(1)
                if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(project.path)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if let date = project.lastActivity {
                    Text(date.shortRelativeString()).font(.caption).foregroundStyle(.secondary)
                }
                if let accounts = project.accounts, !accounts.isEmpty {
                    HStack(spacing: DesignTokens.space4) {
                        ForEach(accounts, id: \.dirName) { acc in
                            AccountBadge(label: acc.label, small: true)
                        }
                    }
                }
            }
            Spacer()
            Text("\(project.sessionCount)")
                .font(.caption).padding(.horizontal, DesignTokens.space6).padding(.vertical, DesignTokens.space2)
                .background(.quaternary, in: Capsule())
        }
    }
}
