import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = ProjectListViewModel()
    @State private var searchText = ""

    var body: some View {
        List(selection: Binding(get: { appState.sidebarSelection }, set: { appState.sidebarSelection = $0 })) {
            ForEach(["claude", "cursor", "codex"], id: \.self) { source in
                let projects = vm.groupedBySource[source] ?? []
                if !projects.isEmpty {
                    Section(sourceLabel(source)) {
                        ForEach(projects, id: \.dirName) { project in
                            ProjectRowView(project: project)
                                .tag(project.dirName)
                                .onTapGesture { appState.selectProject(project.dirName) }
                        }
                    }
                }
            }
        }
        .searchable(text: $vm.searchText, prompt: "Filter projects")
        .navigationTitle("Projects")
        .task { await vm.loadProjects() }
        .refreshable { await vm.loadProjects() }
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
