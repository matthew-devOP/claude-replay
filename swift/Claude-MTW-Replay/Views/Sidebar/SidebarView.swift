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
                            ProjectRowView(project: project, searchText: vm.searchText)
                                .tag(project.dirName)
                        }
                    }
                }
            }
        }
        .searchable(text: $vm.searchText, prompt: "Filter by name or path…")
        .focusable()
        .onKeyPress(.return) {
            if let dirName = appState.sidebarSelection,
               let project = vm.projects.first(where: { $0.dirName == dirName }) {
                appState.selectProject(project)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.upArrow) {
            moveSidebarSelection(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSidebarSelection(by: 1)
            return .handled
        }
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
            ToolbarItem(placement: .automatic) {
                Menu {
                    ForEach(ProjectSortMode.allCases) { mode in
                        Button {
                            vm.sortMode = mode
                        } label: {
                            if mode == vm.sortMode {
                                Label(mode.label, systemImage: "checkmark")
                            } else {
                                Text(mode.label)
                            }
                        }
                    }
                } label: {
                    Label(vm.sortMode.label, systemImage: "arrow.up.arrow.down")
                }
                .help("Sort projects")
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

    // P3.5 — Keyboard navigation for the sidebar project list.
    private func moveSidebarSelection(by delta: Int) {
        let ordered: [String] = ["claude", "cursor", "codex"].flatMap { source in
            (vm.groupedBySource[source] ?? []).map { $0.dirName }
        }
        guard !ordered.isEmpty else { return }
        let currentIndex: Int
        if let sel = appState.sidebarSelection,
           let idx = ordered.firstIndex(of: sel) {
            currentIndex = idx
        } else {
            currentIndex = delta > 0 ? -1 : ordered.count
        }
        let next = max(0, min(ordered.count - 1, currentIndex + delta))
        let nextDir = ordered[next]
        appState.sidebarSelection = nextDir
        if let project = vm.projects.first(where: { $0.dirName == nextDir }) {
            appState.selectProject(project)
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
