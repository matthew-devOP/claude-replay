import SwiftUI
struct ProjectFilesView: View {
    let type: String
    let dirName: String
    @State private var content: String?
    var body: some View {
        ScrollView {
            if let content {
                Text(content).font(.body).textSelection(.enabled).padding()
            } else {
                EmptyStateView(icon: "doc.text", title: "\(type.uppercased()).md not found", subtitle: "")
            }
        }
        .task { loadContent() }
    }
    private func loadContent() {
        let path = SessionDiscovery.claudeDirToProjectPath(dirName)
        let filePath = type == "claude" ? "\(path)/CLAUDE.md" : FileManager.default.homeDirectoryURL.appendingPathComponent(".claude/projects/\(dirName)/memory/MEMORY.md").path
        content = try? String(contentsOfFile: filePath, encoding: .utf8)
    }
}
