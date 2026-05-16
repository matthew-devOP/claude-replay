import Foundation

/// View model exposing tagged sessions grouped by tag name.
@MainActor
@Observable
final class TagsViewModel {
    /// Maps `tag` → sorted list of session paths bearing that tag.
    var tagsGrouped: [String: [String]] = [:]

    func load() {
        let entities = DataStore.shared.getAllTaggedSessions()
        var grouped: [String: [String]] = [:]
        for entity in entities {
            grouped[entity.tag, default: []].append(entity.path)
        }
        // Deduplicate + sort paths within each tag for stable ordering.
        for (key, value) in grouped {
            grouped[key] = Array(Set(value)).sorted()
        }
        tagsGrouped = grouped
    }

    func removeTag(path: String, tag: String) {
        DataStore.shared.removeTag(path: path, tag: tag)
        load()
    }
}
