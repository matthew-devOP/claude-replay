import Foundation

@Observable
final class ProjectListViewModel {
    var projects: [ProjectEntry] = []
    var isLoading = false
    var searchText = ""
    var errorMessage: String?

    func loadProjects() async {
        isLoading = true
        defer { isLoading = false }
        projects = SessionDiscovery.discoverProjects()
    }

    var filteredProjects: [ProjectEntry] {
        guard !searchText.isEmpty else { return projects }
        return projects.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var groupedBySource: [String: [ProjectEntry]] {
        Dictionary(grouping: filteredProjects, by: \.source)
    }
}
