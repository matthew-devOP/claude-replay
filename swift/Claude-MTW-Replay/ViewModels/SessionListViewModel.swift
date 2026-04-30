import Foundation

/// Sort key for the Sessions column header. Mirrors the web table's
/// sortable headers (Date / Duration / Turns / Size).
enum SessionSortKey: String, CaseIterable, Identifiable {
    case date, duration, turns, size
    var id: String { rawValue }
}

@Observable
@MainActor
final class SessionListViewModel {
    var sessions: [SessionEntry] = []
    var isLoading = false
    var sortAscending = false
    var sortKey: SessionSortKey = .date
    var searchText = ""

    /// Sessions selected for the Compare action. We cap at 2 (the diff
    /// view shows two columns); selecting a third drops the oldest.
    var compareSelection: Set<String> = []
    var compareMode: Bool = false

    /// Tracks which session paths have an enrichment task in flight so
    /// scrolling through the table doesn't fan out duplicate parses.
    private var enriching: Set<String> = []

    func loadSessions(projectDirName: String, source: String = "claude", claudeAccountDir: String = ".claude") async {
        isLoading = true
        defer { isLoading = false }
        compareSelection.removeAll()
        compareMode = false
        if let details = SessionDiscovery.getProjectDetails(source: source, dirName: projectDirName, claudeAccountDir: claudeAccountDir) {
            sessions = details.sessions
        } else {
            sessions = []
        }
    }

    var filteredSessions: [SessionEntry] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matched = q.isEmpty ? sessions : sessions.filter {
            $0.sessionId.lowercased().contains(q) ||
            ($0.preview ?? "").lowercased().contains(q)
        }
        return matched.sorted(by: comparator(key: sortKey, ascending: sortAscending))
    }

    func toggleCompareSelection(_ path: String) {
        if compareSelection.contains(path) {
            compareSelection.remove(path)
        } else {
            if compareSelection.count >= 2 {
                // FIFO drop oldest by re-creating from the trailing two paths.
                if let first = compareSelection.first { compareSelection.remove(first) }
            }
            compareSelection.insert(path)
        }
    }

    /// Kick off a background enrichment for a session if one isn't running.
    /// Safe to call from `.onAppear` for every visible row.
    func enrichIfNeeded(_ entry: SessionEntry) {
        guard entry.preview == nil, !enriching.contains(entry.path) else { return }
        enriching.insert(entry.path)
        let path = entry.path
        Task.detached(priority: .utility) { [weak self] in
            let patch = SessionMetaService.meta(for: path)
            await self?.applyMeta(path: path, patch: patch)
        }
    }

    private func applyMeta(path: String, patch: SessionEntry.MetaPatch) {
        if let idx = sessions.firstIndex(where: { $0.path == path }) {
            sessions[idx].apply(patch)
        }
        enriching.remove(path)
    }

    // MARK: - Comparators

    private func comparator(key: SessionSortKey, ascending: Bool) -> (SessionEntry, SessionEntry) -> Bool {
        let mul = ascending ? 1 : -1
        return { a, b in
            switch key {
            case .date:
                let av = a.date ?? .distantPast, bv = b.date ?? .distantPast
                return av < bv ? mul == 1 : (av > bv ? mul == -1 : false)
            case .duration:
                let av = a.durationSeconds ?? 0, bv = b.durationSeconds ?? 0
                return av < bv ? mul == 1 : (av > bv ? mul == -1 : false)
            case .turns:
                let av = a.turnCount ?? 0, bv = b.turnCount ?? 0
                return av < bv ? mul == 1 : (av > bv ? mul == -1 : false)
            case .size:
                return a.size < b.size ? mul == 1 : (a.size > b.size ? mul == -1 : false)
            }
        }
    }
}
