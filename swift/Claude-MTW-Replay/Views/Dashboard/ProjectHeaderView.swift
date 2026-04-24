import SwiftUI
struct ProjectHeaderView: View {
    let project: ProjectEntry

    private static let dateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    @State private var resolvedPath: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.name).font(.title).bold()
            Text(resolvedPath).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Label("\(project.sessionCount) session\(project.sessionCount == 1 ? "" : "s")",
                      systemImage: "doc.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let lastActivity = project.lastActivity {
                    Label(Self.dateFormatter.localizedString(for: lastActivity, relativeTo: Date()),
                          systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .task(id: project.dirName) {
            resolvedPath = SessionDiscovery.claudeDirToProjectPath(project.dirName)
        }
    }
}
