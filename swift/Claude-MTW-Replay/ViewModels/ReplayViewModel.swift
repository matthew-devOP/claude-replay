import Foundation

@Observable
final class ReplayViewModel {
    var turns: [Turn] = []
    var currentTurnIndex: Int = 0
    var revealedBlockCount: Int = 0
    var isPlaying = false
    var speed: Double = 1.0
    var showThinking = true
    var showToolCalls = true
    var bookmarks: [Bookmark] = []
    var isLoading = false
    var errorMessage: String?

    /// Identifies the bookmark store on disk. Set by `loadSession` (disk path)
    /// or `loadImportedSession` (ephemeral key). `nil` disables persistence.
    private var bookmarksKey: String?

    private var playbackTask: Task<Void, Never>?

    static let speedSteps: [Double] = [0.5, 1, 2, 3, 5, 10, 15, 20]

    var currentTurn: Turn? {
        guard currentTurnIndex > 0, currentTurnIndex <= turns.count else { return nil }
        return turns[currentTurnIndex - 1]
    }

    var progress: Double {
        guard !turns.isEmpty else { return 0 }
        return Double(currentTurnIndex) / Double(turns.count)
    }

    func loadSession(path: URL) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let text = try String(contentsOf: path, encoding: .utf8)
            turns = TranscriptParser.parseTranscriptFromText(text)
            currentTurnIndex = 0
            revealedBlockCount = 0
            bookmarksKey = "bookmarks-\(path.path)"
            loadPersistedBookmarks()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Populate the VM from an in-memory imported session (HTML import).
    /// No disk reads. Bookmarks come from the importer; persistence is
    /// keyed by a synthetic id so edits survive within the app session.
    func loadImportedSession(_ session: ImportedSession) {
        pause()
        turns = session.turns
        currentTurnIndex = 0
        revealedBlockCount = 0
        bookmarksKey = "bookmarks-imported-\(session.id.uuidString)"
        // Imported bookmarks take precedence over anything persisted under
        // a previously-used synthetic id (which can't happen unless the
        // user re-imports the same UUID — defensive only).
        bookmarks = session.bookmarks.sorted { $0.turn < $1.turn }
        persistBookmarks()
    }

    // MARK: - Bookmarks

    /// Add a bookmark at `turnIndex` with `label`. Dedups on `turn` —
    /// re-adding at the same index replaces the existing entry.
    func addBookmark(turnIndex: Int, label: String) {
        let clamped = max(0, min(turnIndex, max(turns.count, 0)))
        bookmarks.removeAll { $0.turn == clamped }
        bookmarks.append(Bookmark(turn: clamped, label: label))
        bookmarks.sort { $0.turn < $1.turn }
        persistBookmarks()
    }

    func removeBookmark(id: UUID) {
        bookmarks.removeAll { $0.id == id }
        persistBookmarks()
    }

    func updateBookmark(id: UUID, label: String) {
        guard let idx = bookmarks.firstIndex(where: { $0.id == id }) else { return }
        let existing = bookmarks[idx]
        bookmarks[idx] = Bookmark(id: existing.id, turn: existing.turn, label: label)
        persistBookmarks()
    }

    /// Decode bookmarks JSON in the CLI-compatible format:
    /// `[{"turn": 5, "label": "First failure"}, ...]`. Replaces current list.
    func loadBookmarksJSON(_ data: Data) throws {
        let decoder = JSONDecoder()
        // CLI uses `{turn, label}`; our `Bookmark` adds an optional `id`
        // which Decodable handles via UUID() default in init below.
        struct WireBookmark: Decodable {
            let turn: Int
            let label: String
            let id: UUID?
        }
        let wire = try decoder.decode([WireBookmark].self, from: data)
        bookmarks = wire
            .map { Bookmark(id: $0.id ?? UUID(), turn: $0.turn, label: $0.label) }
            .sorted { $0.turn < $1.turn }
        persistBookmarks()
    }

    /// Encode bookmarks for export. Pretty-printed, CLI-compatible
    /// (`turn`, `label` keys; `id` included for round-trip stability).
    func bookmarksJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(bookmarks)
    }

    // MARK: - Persistence

    private func loadPersistedBookmarks() {
        guard let key = bookmarksKey,
              let data = UserDefaults.standard.data(forKey: key)
        else {
            bookmarks = []
            return
        }
        do {
            try loadBookmarksJSONInternal(data)
        } catch {
            bookmarks = []
        }
    }

    /// Internal variant that does NOT re-persist — used when hydrating
    /// from UserDefaults to avoid a write-loop.
    private func loadBookmarksJSONInternal(_ data: Data) throws {
        bookmarks = try JSONDecoder().decode([Bookmark].self, from: data)
            .sorted { $0.turn < $1.turn }
    }

    private func persistBookmarks() {
        guard let key = bookmarksKey else { return }
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func togglePlay() {
        if isPlaying { pause() } else { play() }
    }

    func play() {
        playbackTask?.cancel()
        isPlaying = true
        playbackTask = Task { @MainActor in
            while isPlaying && currentTurnIndex < turns.count {
                if currentTurnIndex == 0 { currentTurnIndex = 1; revealedBlockCount = 0 }
                let turn = turns[currentTurnIndex - 1]
                while revealedBlockCount < turn.blocks.count && isPlaying {
                    revealedBlockCount += 1
                    let delay = adaptiveDelay(for: turn, blockIndex: revealedBlockCount - 1)
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                if isPlaying && currentTurnIndex < turns.count {
                    currentTurnIndex += 1
                    revealedBlockCount = 0
                    try? await Task.sleep(nanoseconds: UInt64(0.5 / speed * 1_000_000_000))
                }
            }
            isPlaying = false
        }
    }

    func pause() {
        isPlaying = false
        playbackTask?.cancel()
    }

    func stepForward() {
        pause()
        if currentTurnIndex == 0 { currentTurnIndex = 1; revealedBlockCount = 0; return }
        let turn = turns[currentTurnIndex - 1]
        if revealedBlockCount < turn.blocks.count {
            revealedBlockCount += 1
        } else if currentTurnIndex < turns.count {
            currentTurnIndex += 1
            revealedBlockCount = 0
        }
    }

    func stepBack() {
        pause()
        if revealedBlockCount > 0 { revealedBlockCount -= 1; return }
        if currentTurnIndex > 1 {
            currentTurnIndex -= 1
            revealedBlockCount = turns[currentTurnIndex - 1].blocks.count
        } else { currentTurnIndex = 0 }
    }

    func nextTurn() {
        pause()
        if currentTurnIndex < turns.count {
            currentTurnIndex += 1
            revealedBlockCount = turns[currentTurnIndex - 1].blocks.count
        }
    }

    func prevTurn() {
        pause()
        if currentTurnIndex > 1 {
            currentTurnIndex -= 1
            revealedBlockCount = turns[currentTurnIndex - 1].blocks.count
        } else { currentTurnIndex = 0; revealedBlockCount = 0 }
    }

    func seekToTurn(_ index: Int) {
        pause()
        currentTurnIndex = max(0, min(index, turns.count))
        if currentTurnIndex > 0 { revealedBlockCount = turns[currentTurnIndex - 1].blocks.count }
    }

    private func adaptiveDelay(for turn: Turn, blockIndex: Int) -> Double {
        let block = turn.blocks[blockIndex]
        let charCount: Double
        if block.kind == .toolUse, let tc = block.toolCall {
            // For tool calls, use result length if available, else serialized input length
            if let result = tc.result {
                charCount = Double(result.count)
            } else {
                let inputDesc = tc.input.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
                charCount = Double(inputDesc.count)
            }
        } else {
            charCount = Double(block.text.count)
        }
        let baseDelay = min(max(charCount * 0.03, 0.6), 10.0)
        return baseDelay / speed
    }

}
