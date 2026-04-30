import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = SessionListViewModel()
    @State private var selectedTab = "sessions"
    @State private var compareSheetPaths: ComparePathsWrapper?

    var body: some View {
        VStack(spacing: 0) {
            if let dirName = appState.selectedProjectDirName,
               let project = appState.selectedProject {
                ProjectHeaderView(project: project, sessions: vm.sessions)
                Picker("", selection: $selectedTab) {
                    Text("Sessions (\(vm.sessions.count))").tag("sessions")
                    Text("Stats").tag("stats")
                    Text("Plans").tag("plans")
                    Text("CLAUDE.md").tag("claude")
                    Text("MEMORY.md").tag("memory")
                }
                .pickerStyle(.segmented).padding(.horizontal)
                if vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    switch selectedTab {
                    case "sessions":
                        SessionTableView(vm: vm, onCompare: openCompare)
                    case "stats":
                        StatsView()
                    case "plans":
                        PlansListView(projectPath: project.path)
                    case "claude":
                        ProjectFilesView(type: "claude", dirName: dirName)
                    case "memory":
                        ProjectFilesView(type: "memory", dirName: dirName)
                    default:
                        EmptyView()
                    }
                }
            } else {
                EmptyStateView(icon: "square.grid.2x2", title: "Select a Project", subtitle: "Choose a project from the sidebar")
            }
        }
        .task(id: "\(appState.selectedProjectDirName ?? "")|\(appState.claudeAccountDir)") {
            if let d = appState.selectedProjectDirName {
                await vm.loadSessions(projectDirName: d, source: appState.selectedProjectSource, claudeAccountDir: appState.claudeAccountDir)
            }
        }
        .sheet(item: $compareSheetPaths) { wrapped in
            SessionCompareView(leftPath: wrapped.left, rightPath: wrapped.right)
                .frame(minWidth: 1100, minHeight: 700)
        }
    }

    private func openCompare() {
        let paths = Array(vm.compareSelection)
        guard paths.count == 2 else { return }
        compareSheetPaths = ComparePathsWrapper(left: paths[0], right: paths[1])
    }
}

private struct ComparePathsWrapper: Identifiable {
    let left: String
    let right: String
    var id: String { "\(left)|\(right)" }
}
