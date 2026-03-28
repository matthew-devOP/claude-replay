import SwiftUI
struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = SessionListViewModel()
    @State private var selectedTab = "sessions"
    var body: some View {
        VStack(spacing: 0) {
            if let dirName = appState.selectedProjectDirName {
                ProjectHeaderView(dirName: dirName)
                Picker("", selection: $selectedTab) {
                    Text("Sessions").tag("sessions")
                    Text("CLAUDE.md").tag("claude")
                    Text("MEMORY.md").tag("memory")
                }
                .pickerStyle(.segmented).padding(.horizontal)
                switch selectedTab {
                case "sessions": SessionTableView(sessions: vm.filteredSessions)
                case "claude": ProjectFilesView(type: "claude", dirName: dirName)
                case "memory": ProjectFilesView(type: "memory", dirName: dirName)
                default: EmptyView()
                }
            } else {
                EmptyStateView(icon: "square.grid.2x2", title: "Select a Project", subtitle: "Choose a project from the sidebar")
            }
        }
        .task(id: appState.selectedProjectDirName) {
            if let d = appState.selectedProjectDirName { await vm.loadSessions(projectDirName: d) }
        }
    }
}
