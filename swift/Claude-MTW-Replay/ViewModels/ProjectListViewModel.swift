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

    // MARK: - FileWatcher state (P0.6)
    /// Live watchers for the session root directories.  Reloaded
    /// whenever `claudeAccountDir` changes.
    @ObservationIgnored private var watchers: [FileWatcher] = []
    /// Account dir the current watchers are scoped to (so we can detect
    /// when the user switches accounts and restart).
    @ObservationIgnored private var watchedAccountDir: String?
    /// Pending debounced reload task — cancelled on each new fs event.
    @ObservationIgnored private var debounceTask: Task<Void, Never>?

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.sortKey) ?? ProjectSortMode.lastActivityDesc.rawValue
        self.sortMode = ProjectSortMode(rawValue: raw) ?? .lastActivityDesc
    }

    deinit {
        debounceTask?.cancel()
        watchers.forEach { $0.stop() }
        watchers.removeAll()
    }

    func loadProjects(claudeAccountDir: String = ".claude") async {
        isLoading = true
        defer { isLoading = false }
        projects = claudeAccountDir == AccountStore.allDirName
            ? SessionDiscovery.discoverProjectsAll()
            : SessionDiscovery.discoverProjects(claudeAccountDir: claudeAccountDir)
        // Auto-start (or restart) watchers after the first load, so the
        // sidebar refreshes on its own when new sessions land on disk.
        if watchers.isEmpty || watchedAccountDir != claudeAccountDir {
            startWatching(claudeAccountDir: claudeAccountDir)
        }
    }

    /// Begin watching the session root directories.  Re-entrant — stops
    /// previous watchers first.
    func startWatching(claudeAccountDir: String) {
        stopWatching()
        watchedAccountDir = claudeAccountDir
        watchers = FileWatcher.watchSessionDirectories { [weak self] _, _ in
            self?.scheduleReload(claudeAccountDir: claudeAccountDir)
        }
    }

    /// Cancel pending reloads and tear down all live watchers.
    func stopWatching() {
        debounceTask?.cancel()
        debounceTask = nil
        watchers.forEach { $0.stop() }
        watchers.removeAll()
        watchedAccountDir = nil
    }

    /// Coalesce bursts of filesystem events into a single reload 500ms
    /// after the last notification.  Safe to call from any queue.
    private func scheduleReload(claudeAccountDir: String) {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            await self?.loadProjects(claudeAccountDir: claudeAccountDir)
        }
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
