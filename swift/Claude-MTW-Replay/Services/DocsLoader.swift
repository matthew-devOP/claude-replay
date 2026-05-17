import Foundation

@MainActor
enum DocsLoader {
    private static var cache: [String: String] = [:]

    static func load(topicId: String) -> String? {
        if let cached = cache[topicId] { return cached }
        let bundles: [Bundle] = [Bundle.main, Bundle(for: BundleToken.self)]
        for bundle in bundles {
            // Resources/Docs/<topic-id>.md
            if let url = bundle.url(forResource: topicId, withExtension: "md", subdirectory: "Docs"),
               let s = try? String(contentsOf: url, encoding: .utf8) {
                cache[topicId] = s
                return s
            }
            // Fallback: flat resources path
            if let url = bundle.url(forResource: topicId, withExtension: "md"),
               let s = try? String(contentsOf: url, encoding: .utf8) {
                cache[topicId] = s
                return s
            }
        }
        return nil
    }

    /// Full-text search across all topics. Returns sorted (topicId, snippet) results.
    static func search(_ query: String) -> [(topic: DocTopic, snippet: String)] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        var hits: [(topic: DocTopic, snippet: String)] = []
        for topic in DocTopic.catalog {
            guard let content = load(topicId: topic.id) else { continue }
            let lower = content.lowercased()
            if let range = lower.range(of: q) {
                let lineStart = lower[..<range.lowerBound].lastIndex(of: "\n").map { lower.index(after: $0) } ?? lower.startIndex
                let lineEnd = lower[range.upperBound...].firstIndex(of: "\n") ?? lower.endIndex
                let snippet = String(content[lineStart..<lineEnd])
                hits.append((topic, snippet))
            }
        }
        return hits
    }

    private final class BundleToken {}
}
