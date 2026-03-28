import SwiftUI
struct GitView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = GitViewModel()
    var body: some View {
        if let info = vm.gitInfo {
            ScrollView { VStack(alignment: .leading, spacing: 16) {
                GitInfoView(info: info)
                if let details = vm.gitDetails { CommitLogView(details: details); GitGraphView(graph: details.graph) }
                GitActionsView(projectPath: appState.selectedProjectDirName.map { SessionDiscovery.claudeDirToProjectPath($0) } ?? "")
            }.padding() }
        } else if vm.isLoading { ProgressView() }
        else { EmptyStateView(icon: "arrow.triangle.branch", title: "No Git Info", subtitle: "Select a project with a git repository") }
    }
}
