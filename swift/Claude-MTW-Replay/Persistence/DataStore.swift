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
            PermissionDecisionEntity.self,
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

    // MARK: - Chat Branching (G2)

    /// G2 — fork a session at the N-th user turn. Truncates the JSONL on
    /// disk via `SessionForker` (so resuming the new file picks up at the
    /// cut point) and registers a SwiftData row that points back at the
    /// source. Returns the new session path so callers can immediately
    /// navigate to it. The branch row starts with empty `turnsJSON` —
    /// it'll be filled in normally by `upsertChatTranscript` once the
    /// user sends their first message in the branched chat.
    @discardableResult
    func forkSession(
        sourceSessionPath: String,
        atTurnIndex turnIndex: Int,
        label: String? = nil
    ) throws -> String {
        let newURL = try SessionForker.fork(
            sourcePath: sourceSessionPath,
            atTurnIndex: turnIndex,
            label: label
        )
        let parent = getChatTranscript(sessionPath: sourceSessionPath)

        let entity = ChatTranscriptEntity(
            sessionPath: newURL.path,
            projectPath: parent?.projectPath ?? "",
            accountDir: parent?.accountDir ?? ".claude",
            turnsJSON: Data("[]".utf8),  // empty; filled by first send()
            lastUpdated: .now,
            costUsd: 0,
            model: parent?.model,
            displayName: label
        )
        entity.parentSessionId = sourceSessionPath
        // Trace back to the *root* original session so sibling branches
        // share one ancestor even when the user forks a fork.
        entity.branchOfSessionId = parent?.branchOfSessionId ?? sourceSessionPath
        entity.branchLabel = label
        context.insert(entity)
        try? context.save()
        return newURL.path
    }

    /// G2 — list all direct child branches forked from `sessionPath`.
    /// Returns rows newest-first so the most recent experiment surfaces
    /// at the top of `ChatBranchListView`.
    func getBranches(sessionPath: String) -> [ChatTranscriptEntity] {
        let descriptor = FetchDescriptor<ChatTranscriptEntity>(
            predicate: #Predicate { $0.parentSessionId == sessionPath },
            sortBy: [SortDescriptor(\.lastUpdated, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
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

    // MARK: - Permission Decisions (G8)

    /// G8 — lookup a previously-remembered allow/deny for this
    /// (session, tool, signature) tuple. Returns `nil` when the user
    /// hasn't picked "always" for an identical prompt yet, in which
    /// case the UI must surface the modal to ask interactively.
    func shouldAutoApprove(
        sessionPath: String,
        toolName: String,
        signature: String
    ) -> PermissionAction? {
        let descriptor = FetchDescriptor<PermissionDecisionEntity>(
            predicate: #Predicate {
                $0.sessionPath == sessionPath &&
                $0.toolName == toolName &&
                $0.signature == signature
            }
        )
        guard let entity = try? context.fetch(descriptor).first else { return nil }
        return PermissionAction(rawValue: entity.action)
    }

    /// G8 — store an "always allow / always deny" pick so future
    /// identical prompts auto-resolve. Idempotent: an existing row for
    /// the same (sessionPath, toolName, signature) tuple is overwritten
    /// in-place rather than duplicated so the user can change their
    /// mind without leaving stale ghost decisions behind.
    func recordDecision(
        sessionPath: String,
        toolName: String,
        signature: String,
        action: PermissionAction
    ) {
        let descriptor = FetchDescriptor<PermissionDecisionEntity>(
            predicate: #Predicate {
                $0.sessionPath == sessionPath &&
                $0.toolName == toolName &&
                $0.signature == signature
            }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.action = action.rawValue
            existing.createdAt = .now
        } else {
            let entity = PermissionDecisionEntity(
                sessionPath: sessionPath,
                toolName: toolName,
                signature: signature,
                action: action.rawValue
            )
            context.insert(entity)
        }
        try? context.save()
    }
}
