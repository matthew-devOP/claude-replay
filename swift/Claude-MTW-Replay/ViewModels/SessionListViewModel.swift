import Foundation

/// Sort key for the Sessions column header. Mirrors the web table's
/// sortable headers (Date / Duration / Turns / Size).
enum SessionSortKey: String, CaseIterable, Identifiable {
    case created, date, duration, turns, size
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

    // MARK: - Chain selection (P1.2 — multi-session chaining)
    /// Session paths checked in the table for chained replay.
    var selectedPaths: Set<String> = []
    /// When `true`, the table renders multi-select checkboxes for chaining.
    var chainMode: Bool = false
    /// Last error message from `chainSelected()` — surfaced in UI.
    var chainErrorMessage: String? = nil

    /// Tracks which session paths have an enrichment task in flight so
    /// scrolling through the table doesn't fan out duplicate parses.
    private var enriching: Set<String> = []

    // MARK: - FileWatcher state (P0.6)
    /// Live watcher for the currently selected project directory.
    @ObservationIgnored private var watchers: [FileWatcher] = []
    /// Coordinates (source/dirName/account) for the active watcher so we
    /// know when to tear down and rebuild after a selection change.
    @ObservationIgnored private var watchedKey: String?
    /// Pending debounced reload — cancelled on each new fs event.
    @ObservationIgnored private var debounceTask: Task<Void, Never>?

    deinit {
        debounceTask?.cancel()
        watchers.forEach { $0.stop() }
        watchers.removeAll()
    }

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
        // Refresh watchers when the active project changes so disk-side
        // edits (new sessions, JSONL extensions) flow back into the table.
        let key = "\(source)|\(claudeAccountDir)|\(projectDirName)"
        if watchedKey != key {
            startWatching(projectDirName: projectDirName, source: source, claudeAccountDir: claudeAccountDir)
        }
    }

    /// Begin watching the JSONL directory backing the current project.
    /// Re-entrant — tears down any previous watcher first.  Only
    /// `source == "claude"` is currently supported (matches
    /// `SessionDiscovery.getProjectDetails`).
    func startWatching(projectDirName: String, source: String = "claude", claudeAccountDir: String = ".claude") {
        stopWatching()
        watchedKey = "\(source)|\(claudeAccountDir)|\(projectDirName)"
        guard source == "claude" else { return }

        let fm = FileManager.default
        // In ALL mode the same project can live under several accounts —
        // watch each account's copy so a new session in any of them refreshes
        // the aggregated table.
        let dirs = claudeAccountDir == AccountStore.allDirName
            ? AccountStore.realAccountDirs()
            : [claudeAccountDir]
        var newWatchers: [FileWatcher] = []
        for dir in dirs {
            let projURL = fm.homeDirectoryURL
                .appendingPathComponent(dir)
                .appendingPathComponent("projects")
                .appendingPathComponent(projectDirName)
            guard fm.isDirectory(at: projURL.path) else { continue }

            let watcher = FileWatcher(url: projURL) { [weak self] _, _ in
                // FileWatcher fires on its private DispatchQueue; hop onto
                // the main actor to mutate VM state safely.
                Task { @MainActor [weak self] in
                    self?.scheduleReload(projectDirName: projectDirName,
                                         source: source,
                                         claudeAccountDir: claudeAccountDir)
                }
            }
            watcher.start()
            newWatchers.append(watcher)
        }
        watchers = newWatchers
    }

    /// Tear down any live watcher and drop pending reloads.
    func stopWatching() {
        debounceTask?.cancel()
        debounceTask = nil
        watchers.forEach { $0.stop() }
        watchers.removeAll()
        watchedKey = nil
    }

    /// Debounce filesystem bursts; reload the session list 500ms after
    /// the last event.  Safe to call from FileWatcher's worker queue.
    private func scheduleReload(projectDirName: String,
                                source: String,
                                claudeAccountDir: String) {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            await self?.loadSessions(projectDirName: projectDirName,
                                     source: source,
                                     claudeAccountDir: claudeAccountDir)
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

    // MARK: - Chain selection helpers (P1.2)

    /// Toggle a session path in the chain selection set.
    func toggleSelection(path: String) {
        if selectedPaths.contains(path) {
            selectedPaths.remove(path)
        } else {
            selectedPaths.insert(path)
        }
    }

    /// Parse-and-chain the currently selected paths in chronological order.
    /// Returns `nil` (and sets `chainErrorMessage`) on failure.
    func chainSelected() async -> [Turn]? {
        chainErrorMessage = nil
        // Order paths by the session's known date when available, so the
        // parser's secondary sort by first-turn timestamp has a stable
        // starting point for sessions lacking timestamps.
        let dateByPath: [String: Date] = Dictionary(uniqueKeysWithValues:
            sessions.compactMap { entry in
                entry.date.map { (entry.path, $0) }
            }
        )
        let orderedPaths = selectedPaths.sorted { lhs, rhs in
            let l = dateByPath[lhs] ?? .distantPast
            let r = dateByPath[rhs] ?? .distantPast
            return l < r
        }
        do {
            return try await TranscriptParser.parseAndChain(filePaths: orderedPaths)
        } catch {
            chainErrorMessage = error.localizedDescription
            return nil
        }
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
            case .created:
                let av = a.createdDate ?? a.date ?? .distantPast
                let bv = b.createdDate ?? b.date ?? .distantPast
                return av < bv ? mul == 1 : (av > bv ? mul == -1 : false)
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
