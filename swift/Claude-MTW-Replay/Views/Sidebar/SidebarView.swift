import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = ProjectListViewModel()
    @State private var searchText = ""

    var body: some View {
        List(selection: Binding(
            get: { appState.sidebarSelection },
            set: { newValue in
                appState.sidebarSelection = newValue
                if let dirName = newValue,
                   let project = vm.projects.first(where: { $0.dirName == dirName }) {
                    appState.selectProject(project)
                }
            }
        )) {
            FavoritesSectionView()
            TagsSectionView()
            ForEach(["claude", "cursor", "codex"], id: \.self) { source in
                let projects = vm.groupedBySource[source] ?? []
                if !projects.isEmpty {
                    Section(sourceLabel(source)) {
                        ForEach(projects, id: \.dirName) { project in
                            ProjectRowView(project: project)
                                .tag(project.dirName)
                        }
                    }
                }
            }
        }
        .searchable(text: $vm.searchText, prompt: "Filter projects")
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Image("mascot")
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 20)
            }
            ToolbarItem(placement: .automatic) {
                AccountSwitcherMenu()
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await vm.loadProjects(claudeAccountDir: appState.claudeAccountDir) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh Projects")
            }
        }
        .task(id: appState.claudeAccountDir) {
            await vm.loadProjects(claudeAccountDir: appState.claudeAccountDir)
        }
    }

    private func sourceLabel(_ source: String) -> String {
        switch source {
        case "claude": return "Claude Code"
        case "cursor": return "Cursor"
        case "codex": return "Codex CLI"
        default: return source
        }
    }
}
