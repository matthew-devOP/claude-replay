import SwiftUI
struct ProjectHeaderView: View {
    let dirName: String
    var body: some View {
        let path = SessionDiscovery.claudeDirToProjectPath(dirName)
        VStack(alignment: .leading, spacing: 4) {
            Text(URL(fileURLWithPath: path).lastPathComponent).font(.title).bold()
            Text(path).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
