import SwiftUI

struct ProjectRowView: View {
    @Environment(AppState.self) private var appState
    let project: ProjectEntry

    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundStyle(appState.theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name).font(.headline).lineLimit(1)
                if let date = project.lastActivity {
                    Text(date.shortRelativeString()).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(project.sessionCount)")
                .font(.caption).padding(.horizontal, 6).padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
        }
    }
}
