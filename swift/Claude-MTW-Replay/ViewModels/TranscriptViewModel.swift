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
        turns = TranscriptParser.parseTranscript(text: text)
    }

    var filteredTurns: [Turn] {
        turns.filter { turn in
            if !searchText.isEmpty {
                let match = turn.userText.localizedCaseInsensitiveContains(searchText) ||
                    turn.blocks.contains { $0.text.localizedCaseInsensitiveContains(searchText) }
                if !match { return false }
            }
            return true
        }
    }

    func nextMatch() { if matchCount > 0 { currentMatchIndex = (currentMatchIndex + 1) % matchCount } }
    func prevMatch() { if matchCount > 0 { currentMatchIndex = (currentMatchIndex - 1 + matchCount) % matchCount } }
}
