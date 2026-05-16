import Foundation
import SwiftData

/// SwiftData entity caching the latest live-chat transcript for a session
/// (G1 — local chat history persistence). Stored as JSON-encoded `[Turn]`
/// so the entity stays decoupled from the model layout; UI re-decodes on
/// demand. Unique per `sessionPath` so resuming a chat just updates the
/// existing row.
@Model
final class ChatTranscriptEntity {
    #Unique<ChatTranscriptEntity>([\.sessionPath])

    @Attribute(.unique) var sessionPath: String
    var projectPath: String
    var accountDir: String
    var turnsJSON: Data
    var lastUpdated: Date
    var costUsd: Double
    var model: String?
    var displayName: String?
    /// G6 — JSON-encoded `[String]` of tools the user enabled for this
    /// session. `nil` means "never customised; use the picker default".
    /// Optional + default `nil` to stay schema-compatible with rows
    /// created by Sprint 4-A before this field existed.
    var enabledToolsJSON: Data? = nil

    // MARK: - G2 — Conversation forking / branching
    //
    // All three fields are optional + default `nil` so existing rows
    // upgrade in-place without a SwiftData migration. They describe the
    // ancestry of a branch row:
    //
    //  * `parentSessionId` — the immediate parent we forked from (the
    //    session the user was viewing when they hit "Branch from here").
    //  * `branchOfSessionId` — the *root* session for the whole branch
    //    tree, so we can group sibling branches under a single original
    //    conversation even after multiple fork-of-a-fork hops.
    //  * `branchLabel` — short human label shown in the branch list
    //    (e.g. "Branch May 16 14:32"). `displayName` is reserved for the
    //    chat's own title; we keep the label separate so renaming the
    //    chat doesn't wipe the branch tag.
    var parentSessionId: String? = nil
    var branchOfSessionId: String? = nil
    var branchLabel: String? = nil

    init(
        sessionPath: String,
        projectPath: String,
        accountDir: String,
        turnsJSON: Data,
        lastUpdated: Date = .now,
        costUsd: Double = 0,
        model: String? = nil,
        displayName: String? = nil,
        enabledToolsJSON: Data? = nil
    ) {
        self.sessionPath = sessionPath
        self.projectPath = projectPath
        self.accountDir = accountDir
        self.turnsJSON = turnsJSON
        self.lastUpdated = lastUpdated
        self.costUsd = costUsd
        self.model = model
        self.displayName = displayName
        self.enabledToolsJSON = enabledToolsJSON
    }
}
