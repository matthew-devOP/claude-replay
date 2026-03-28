import Foundation

enum SearchService {
    static func search(query: String, in projectDirName: String, maxFiles: Int = 30, maxResults: Int = 50) -> [SearchResult] {
        let fm = FileManager.default
        let projDir = fm.homeDirectoryURL.appendingPathComponent(".claude/projects/\(projectDirName)")
        let files = fm.jsonlFiles(in: projDir).prefix(maxFiles)
        var results: [SearchResult] = []
        let lowerQuery = query.lowercased()

        for file in files {
            let path = projDir.appendingPathComponent(file)
            guard let text = try? String(contentsOf: path, encoding: .utf8) else { continue }
            let turns = TranscriptParser.parseTranscript(text: text)
            for turn in turns {
                if turn.userText.lowercased().contains(lowerQuery) {
                    results.append(SearchResult(id: UUID(), projectName: projectDirName, sessionPath: path.path, turnIndex: turn.index, matchText: String(turn.userText.prefix(200)), role: "User", context: ""))
                }
                for block in turn.blocks where block.text.lowercased().contains(lowerQuery) {
                    results.append(SearchResult(id: UUID(), projectName: projectDirName, sessionPath: path.path, turnIndex: turn.index, matchText: String(block.text.prefix(200)), role: block.kind.rawValue, context: ""))
                }
                if results.count >= maxResults { return results }
            }
        }
        return results
    }
}
