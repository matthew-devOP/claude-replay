import Foundation

@Observable
final class EditorViewModel {
    var originalTurns: [Turn] = []
    var workingTurns: [Turn] = []
    var excludedTurns: Set<Int> = []
    var bookmarks: [Bookmark] = []
    var selectedTurnIndex: Int? = nil
    var isLoading = false

    var hasEdits: Bool {
        workingTurns != originalTurns || !excludedTurns.isEmpty || !bookmarks.isEmpty
    }

    func loadSession(path: URL) async {
        isLoading = true
        defer { isLoading = false }
        guard let text = try? String(contentsOf: path, encoding: .utf8) else { return }
        originalTurns = TranscriptParser.parseTranscriptFromText(text)
        workingTurns = originalTurns
        excludedTurns = []
        bookmarks = []
    }

    func editTurnText(index: Int, newText: String) {
        guard index < workingTurns.count else { return }
        workingTurns[index].userText = newText
    }

    func toggleExclude(index: Int) {
        if excludedTurns.contains(index) { excludedTurns.remove(index) }
        else { excludedTurns.insert(index) }
    }

    func reset() {
        workingTurns = originalTurns
        excludedTurns = []
        bookmarks = []
    }

    func prepareTurnsForExport() -> [Turn] {
        workingTurns.enumerated().compactMap { index, turn in
            excludedTurns.contains(index) ? nil : turn
        }.enumerated().map { newIndex, turn in
            var t = turn; t.index = newIndex + 1; return t
        }
    }
}
