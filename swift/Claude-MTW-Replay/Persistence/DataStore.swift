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
            ChatTranscriptEntity.self,
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

    // MARK: - Chat Transcripts (G1)

    /// Insert-or-update the cached transcript for a chat session. Caller
    /// is responsible for encoding `turns` to JSON; we accept raw `Data`
    /// so the entity stays Codable-agnostic.
    func upsertChatTranscript(
        sessionPath: String,
        projectPath: String,
        accountDir: String,
        turnsJSON: Data,
        costUsd: Double,
        model: String?,
        displayName: String?
    ) {
        let descriptor = FetchDescriptor<ChatTranscriptEntity>(
            predicate: #Predicate { $0.sessionPath == sessionPath }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.projectPath = projectPath
            existing.accountDir = accountDir
            existing.turnsJSON = turnsJSON
            existing.lastUpdated = .now
            existing.costUsd = costUsd
            if let model { existing.model = model }
            if let displayName { existing.displayName = displayName }
        } else {
            let entity = ChatTranscriptEntity(
                sessionPath: sessionPath,
                projectPath: projectPath,
                accountDir: accountDir,
                turnsJSON: turnsJSON,
                lastUpdated: .now,
                costUsd: costUsd,
                model: model,
                displayName: displayName
            )
            context.insert(entity)
        }
        try? context.save()
    }

    func getChatTranscript(sessionPath: String) -> ChatTranscriptEntity? {
        let descriptor = FetchDescriptor<ChatTranscriptEntity>(
            predicate: #Predicate { $0.sessionPath == sessionPath }
        )
        return try? context.fetch(descriptor).first
    }

    /// Recent transcripts within the last `days` days, newest first, capped
    /// by `limit`. Used by `ChatActiveListView` to surface ongoing chats.
    func getRecentChatTranscripts(within days: Int = 7, limit: Int = 20) -> [ChatTranscriptEntity] {
        let cutoff = Date(timeIntervalSinceNow: -Double(days) * 86_400)
        var descriptor = FetchDescriptor<ChatTranscriptEntity>(
            predicate: #Predicate { $0.lastUpdated > cutoff },
            sortBy: [SortDescriptor(\.lastUpdated, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    /// G6 — write/overwrite the enabled-tools list for a session. We
    /// upsert a stub entity if no transcript row exists yet so the user's
    /// pick survives even when they close the chat before sending a
    /// turn (which is when `upsertChatTranscript` normally creates the
    /// row). Caller passes pre-encoded JSON to keep the layer Codable-
    /// agnostic, mirroring how `turnsJSON` is handled above.
    func setEnabledTools(sessionPath: String, toolsJSON: Data) {
        let descriptor = FetchDescriptor<ChatTranscriptEntity>(
            predicate: #Predicate { $0.sessionPath == sessionPath }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.enabledToolsJSON = toolsJSON
            existing.lastUpdated = .now
        } else {
            // No transcript yet — drop a minimal placeholder so the
            // setting still persists. `upsertChatTranscript` later fills
            // in the real fields.
            let entity = ChatTranscriptEntity(
                sessionPath: sessionPath,
                projectPath: "",
                accountDir: "",
                turnsJSON: Data("[]".utf8),
                lastUpdated: .now,
                enabledToolsJSON: toolsJSON
            )
            context.insert(entity)
        }
        try? context.save()
    }

    func deleteChatTranscript(sessionPath: String) {
        let descriptor = FetchDescriptor<ChatTranscriptEntity>(
            predicate: #Predicate { $0.sessionPath == sessionPath }
        )
        if let existing = try? context.fetch(descriptor).first {
            context.delete(existing)
            try? context.save()
        }
    }
}
