import Foundation
import SwiftData

/// SwiftData entity for favorited/pinned sessions.
@Model
final class FavoriteEntity {
    #Unique<FavoriteEntity>([\.path])

    @Attribute(.unique) var path: String
    var sessionId: String
    var preview: String
    var projectDir: String
    var pinnedAt: Date

    init(
        path: String,
        sessionId: String,
        preview: String,
        projectDir: String,
        pinnedAt: Date = Date()
    ) {
        self.path = path
        self.sessionId = sessionId
        self.preview = preview
        self.projectDir = projectDir
        self.pinnedAt = pinnedAt
    }
}
