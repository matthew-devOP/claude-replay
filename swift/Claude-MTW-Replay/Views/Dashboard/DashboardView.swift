import SwiftUI
struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = SessionListViewModel()
    @State private var selectedTab = "sessions"
    var body: some View {
        VStack(spacing: 0) {
            if let dirName = appState.selectedProjectDirName,
               let project = appState.selectedProject {
                ProjectHeaderView(project: project)
                Picker("", selection: $selectedTab) {
                    Text("Sessions").tag("sessions")
                    Text("CLAUDE.md").tag("claude")
                    Text("MEMORY.md").tag("memory")
                }
                .pickerStyle(.segmented).padding(.horizontal)
                if vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    switch selectedTab {
                    case "sessions": SessionTableView(sessions: vm.filteredSessions, sortAscending: $vm.sortAscending)
                    case "claude": ProjectFilesView(type: "claude", dirName: dirName)
                    case "memory": ProjectFilesView(type: "memory", dirName: dirName)
                    default: EmptyView()
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
    }
}
