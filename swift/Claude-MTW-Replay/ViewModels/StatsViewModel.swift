import Foundation

@Observable
final class StatsViewModel {
    var stats: SessionStats?
    var isLoading = false

    func loadStats(path: URL) async {
        isLoading = true
        defer { isLoading = false }
        guard let text = try? String(contentsOf: path, encoding: .utf8) else { return }
        let turns = TranscriptParser.parseTranscript(text: text)
        stats = StatsComputer.compute(turns: turns)
    }
}
