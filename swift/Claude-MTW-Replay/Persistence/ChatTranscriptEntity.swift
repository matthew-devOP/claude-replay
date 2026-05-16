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

    init(
        sessionPath: String,
        projectPath: String,
        accountDir: String,
        turnsJSON: Data,
        lastUpdated: Date = .now,
        costUsd: Double = 0,
        model: String? = nil,
        displayName: String? = nil
    ) {
        self.sessionPath = sessionPath
        self.projectPath = projectPath
        self.accountDir = accountDir
        self.turnsJSON = turnsJSON
        self.lastUpdated = lastUpdated
        self.costUsd = costUsd
        self.model = model
        self.displayName = displayName
    }
}
