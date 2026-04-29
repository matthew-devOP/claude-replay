import Foundation

/// Sort options for the sidebar project list (parity with the web dropdown).
enum ProjectSortMode: String, CaseIterable, Identifiable {
    case lastActivityDesc = "lastActivity-desc"
    case lastActivityAsc  = "lastActivity-asc"
    case firstActivityDesc = "firstActivity-desc"
    case firstActivityAsc  = "firstActivity-asc"
    case sessionCountDesc = "sessionCount-desc"
    case sessionCountAsc  = "sessionCount-asc"
    case nameAsc  = "name-asc"
    case nameDesc = "name-desc"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lastActivityDesc:  return "Last activity ↓"
        case .lastActivityAsc:   return "Last activity ↑"
        case .firstActivityDesc: return "Created ↓"
        case .firstActivityAsc:  return "Created ↑"
        case .sessionCountDesc:  return "Sessions ↓"
        case .sessionCountAsc:   return "Sessions ↑"
        case .nameAsc:           return "Name A→Z"
        case .nameDesc:          return "Name Z→A"
        }
    }
}

@Observable
final class ProjectListViewModel {
    var projects: [ProjectEntry] = []
    var isLoading = false
    var searchText = ""
    var sortMode: ProjectSortMode {
        didSet { UserDefaults.standard.set(sortMode.rawValue, forKey: Self.sortKey) }
    }
    var errorMessage: String?

    private static let sortKey = "projectSortMode"

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.sortKey) ?? ProjectSortMode.lastActivityDesc.rawValue
        self.sortMode = ProjectSortMode(rawValue: raw) ?? .lastActivityDesc
    }

    func loadProjects(claudeAccountDir: String = ".claude") async {
        isLoading = true
        defer { isLoading = false }
        projects = SessionDiscovery.discoverProjects(claudeAccountDir: claudeAccountDir)
    }

    /// Search matches both display name AND filesystem path (case-insensitive).
    var filteredProjects: [ProjectEntry] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let base: [ProjectEntry]
        if q.isEmpty {
            base = projects
        } else {
            base = projects.filter {
                $0.name.localizedCaseInsensitiveContains(q) ||
                $0.path.localizedCaseInsensitiveContains(q)
            }
        }
        return base.sorted(by: comparator(for: sortMode))
    }

    var groupedBySource: [String: [ProjectEntry]] {
        Dictionary(grouping: filteredProjects, by: \.source)
    }

    private func comparator(for mode: ProjectSortMode) -> (ProjectEntry, ProjectEntry) -> Bool {
        switch mode {
        case .lastActivityDesc:
            return { ($0.lastActivity ?? .distantPast) > ($1.lastActivity ?? .distantPast) }
        case .lastActivityAsc:
            return { ($0.lastActivity ?? .distantFuture) < ($1.lastActivity ?? .distantFuture) }
        case .firstActivityDesc:
            return { ($0.firstActivity ?? .distantPast) > ($1.firstActivity ?? .distantPast) }
        case .firstActivityAsc:
            return { ($0.firstActivity ?? .distantFuture) < ($1.firstActivity ?? .distantFuture) }
        case .sessionCountDesc:
            return { $0.sessionCount > $1.sessionCount }
        case .sessionCountAsc:
            return { $0.sessionCount < $1.sessionCount }
        case .nameAsc:
            return { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDesc:
            return { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        }
    }
}
