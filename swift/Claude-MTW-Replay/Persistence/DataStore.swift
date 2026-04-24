import Foundation
import SwiftData

/// Central persistence layer using SwiftData.
@MainActor
final class DataStore {
    static let shared = DataStore()

    let container: ModelContainer

    private init() {
        let schema = Schema([
            SessionMetaEntity.self,
            SessionStatsEntity.self,
            FavoriteEntity.self,
            TagEntity.self,
        ])

        let configuration = ModelConfiguration(
            "ClaudeReplay",
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var context: ModelContext {
        container.mainContext
    }

    // MARK: - Session Meta

    func getCachedMeta(path: String, mtime: Date) -> SessionMetaEntity? {
        let descriptor = FetchDescriptor<SessionMetaEntity>(
            predicate: #Predicate { $0.path == path && $0.fileMtime == mtime }
        )
        return try? context.fetch(descriptor).first
    }

    func setCachedMeta(_ entity: SessionMetaEntity) {
        context.insert(entity)
        try? context.save()
    }

    // MARK: - Session Stats

    func getCachedStats(path: String, mtime: Date) -> SessionStatsEntity? {
        let descriptor = FetchDescriptor<SessionStatsEntity>(
            predicate: #Predicate { $0.path == path && $0.fileMtime == mtime }
        )
        return try? context.fetch(descriptor).first
    }

    func setCachedStats(_ entity: SessionStatsEntity) {
        context.insert(entity)
        try? context.save()
    }

    // MARK: - Favorites

    func getFavorites() -> [FavoriteEntity] {
        let descriptor = FetchDescriptor<FavoriteEntity>(
            sortBy: [SortDescriptor(\.pinnedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func addFavorite(_ entity: FavoriteEntity) {
        context.insert(entity)
        try? context.save()
    }

    func removeFavorite(path: String) {
        let descriptor = FetchDescriptor<FavoriteEntity>(
            predicate: #Predicate { $0.path == path }
        )
        if let existing = try? context.fetch(descriptor).first {
            context.delete(existing)
            try? context.save()
        }
    }

    func isFavorite(path: String) -> Bool {
        let descriptor = FetchDescriptor<FavoriteEntity>(
            predicate: #Predicate { $0.path == path }
        )
        return ((try? context.fetch(descriptor).first) != nil)
    }

    // MARK: - Tags

    func getTags(forPath path: String) -> [TagEntity] {
        let descriptor = FetchDescriptor<TagEntity>(
            predicate: #Predicate { $0.path == path }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func addTag(path: String, tag: String) {
        let entity = TagEntity(path: path, tag: tag)
        context.insert(entity)
        try? context.save()
    }

    func removeTag(path: String, tag: String) {
        let descriptor = FetchDescriptor<TagEntity>(
            predicate: #Predicate { $0.path == path && $0.tag == tag }
        )
        if let existing = try? context.fetch(descriptor).first {
            context.delete(existing)
            try? context.save()
        }
    }

    func setTags(path: String, tags: [String]) {
        let descriptor = FetchDescriptor<TagEntity>(
            predicate: #Predicate { $0.path == path }
        )
        if let existing = try? context.fetch(descriptor) {
            for entity in existing {
                context.delete(entity)
            }
        }
        for tag in tags {
            context.insert(TagEntity(path: path, tag: tag))
        }
        try? context.save()
    }

    func getAllTaggedSessions() -> [TagEntity] {
        let descriptor = FetchDescriptor<TagEntity>()
        return (try? context.fetch(descriptor)) ?? []
    }
}
