import Foundation

@Observable
final class ProjectListViewModel {
    var projects: [ProjectEntry] = []
    var isLoading = false
    var searchText = ""
    var errorMessage: String?

    func loadProjects(claudeAccountDir: String = ".claude") async {
        isLoading = true
        defer { isLoading = false }
        projects = SessionDiscovery.discoverProjects(claudeAccountDir: claudeAccountDir)
    }

    var filteredProjects: [ProjectEntry] {
        guard !searchText.isEmpty else { return projects }
        return projects.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var groupedBySource: [String: [ProjectEntry]] {
        Dictionary(grouping: filteredProjects, by: \.source)
    }
}
