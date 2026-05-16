import Foundation

@Observable
final class EditorViewModel {
    var originalTurns: [Turn] = []
    var workingTurns: [Turn] = []
    var excludedTurns: Set<Int> = []
    var bookmarks: [Bookmark] = []
    var selectedTurnIndex: Int? = nil
    var isLoading = false

    // P3.3 — Autosave editor state
    private var sessionPath: String? = nil
    private var autosaveTask: Task<Void, Never>? = nil

    private struct EditorPersistedState: Codable {
        let excludedTurns: [Int]
        let turnEdits: [Int: String]
    }

    var hasEdits: Bool {
        workingTurns != originalTurns || !excludedTurns.isEmpty || !bookmarks.isEmpty
    }

    func loadSession(path: URL) async {
        isLoading = true
        defer { isLoading = false }
        sessionPath = path.path
        guard let text = try? String(contentsOf: path, encoding: .utf8) else { return }
        originalTurns = TranscriptParser.parseTranscriptFromText(text)
        workingTurns = originalTurns
        excludedTurns = []
        bookmarks = []
        restoreState()
    }

    func editTurnText(index: Int, newText: String) {
        guard index < workingTurns.count else { return }
        workingTurns[index].userText = newText
        scheduleAutosave()
    }

    func toggleExclude(index: Int) {
        if excludedTurns.contains(index) { excludedTurns.remove(index) }
        else { excludedTurns.insert(index) }
        scheduleAutosave()
    }

    func includeAllTurns() {
        excludedTurns = []
        scheduleAutosave()
    }

    func excludeAllTurns() {
        excludedTurns = Set(0..<workingTurns.count)
        scheduleAutosave()
    }

    func excludeBefore(index: Int) {
        guard index > 0 else { excludedTurns = []; scheduleAutosave(); return }
        excludedTurns = Set(0..<index)
        scheduleAutosave()
    }

    func excludeAfter(index: Int) {
        let upper = workingTurns.count
        guard index + 1 < upper else { excludedTurns = []; scheduleAutosave(); return }
        excludedTurns = Set((index + 1)..<upper)
        scheduleAutosave()
    }

    func reset() {
        workingTurns = originalTurns
        excludedTurns = []
        bookmarks = []
        scheduleAutosave()
    }

    // P3.3 — Discard all autosaved edits for this session and reload from disk.
    func discardChanges() {
        let key = "editor-state-\(sessionPath ?? "")"
        UserDefaults.standard.removeObject(forKey: key)
        autosaveTask?.cancel()
        workingTurns = originalTurns
        excludedTurns = []
        bookmarks = []
    }

    // P3.3 — Debounced autosave (2s) of the current editor state.
    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self else { return }
            await MainActor.run { self.persistState() }
        }
    }

    private func persistState() {
        guard let path = sessionPath else { return }
        let key = "editor-state-\(path)"
        // Capture per-turn text edits that diverge from the original transcript.
        var edits: [Int: String] = [:]
        for (idx, turn) in workingTurns.enumerated() {
            if idx < originalTurns.count, turn.userText != originalTurns[idx].userText {
                edits[idx] = turn.userText
            }
        }
        let state = EditorPersistedState(
            excludedTurns: Array(excludedTurns),
            turnEdits: edits
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func restoreState() {
        guard let path = sessionPath else { return }
        let key = "editor-state-\(path)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let state = try? JSONDecoder().decode(EditorPersistedState.self, from: data) else { return }
        excludedTurns = Set(state.excludedTurns)
        for (idx, text) in state.turnEdits {
            guard idx < workingTurns.count else { continue }
            workingTurns[idx].userText = text
        }
    }

    func prepareTurnsForExport() -> [Turn] {
        workingTurns.enumerated().compactMap { index, turn in
            excludedTurns.contains(index) ? nil : turn
        }.enumerated().map { newIndex, turn in
            var t = turn; t.index = newIndex + 1; return t
        }
    }
}
