import Foundation

@Observable
final class TranscriptViewModel {
    var turns: [Turn] = []
    var searchText = ""
    var showUser = true
    var showAssistant = true
    var showTools = true
    var showThinking = true
    var matchCount = 0
    var currentMatchIndex = 0
    var isLoading = false

    func loadSession(path: URL) async {
        isLoading = true
        defer { isLoading = false }
        guard let text = try? String(contentsOf: path, encoding: .utf8) else { return }
        turns = TranscriptParser.parseTranscriptFromText(text)
    }

    var filteredTurns: [Turn] {
        turns.compactMap { turn in
            // Filter blocks based on toggles
            let visibleBlocks = turn.blocks.filter { block in
                switch block.kind {
                case .text:     return showAssistant
                case .thinking: return showThinking
                case .toolUse:  return showTools
                }
            }

            let hasVisibleUser = showUser && !turn.userText.isEmpty
            let hasVisibleBlocks = !visibleBlocks.isEmpty

            // If nothing is visible in this turn, skip it entirely
            guard hasVisibleUser || hasVisibleBlocks else { return nil }

            // Apply search text filter
            if !searchText.isEmpty {
                let userMatch = hasVisibleUser &&
                    turn.userText.localizedCaseInsensitiveContains(searchText)
                let blockMatch = visibleBlocks.contains {
                    $0.text.localizedCaseInsensitiveContains(searchText)
                }
                guard userMatch || blockMatch else { return nil }
            }

            // Return a turn with only the visible blocks
            var filtered = turn
            filtered.blocks = visibleBlocks
            if !showUser { filtered.userText = "" }
            return filtered
        }
    }

    func updateMatchCount() {
        guard !searchText.isEmpty else {
            matchCount = 0
            currentMatchIndex = 0
            return
        }
        var count = 0
        for turn in filteredTurns {
            count += turn.userText.countOccurrences(of: searchText)
            for block in turn.blocks {
                count += block.text.countOccurrences(of: searchText)
            }
        }
        matchCount = count
        if currentMatchIndex >= matchCount { currentMatchIndex = 0 }
    }

    func nextMatch() { if matchCount > 0 { currentMatchIndex = (currentMatchIndex + 1) % matchCount } }
    func prevMatch() { if matchCount > 0 { currentMatchIndex = (currentMatchIndex - 1 + matchCount) % matchCount } }
}
