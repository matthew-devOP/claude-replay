import Foundation
import SwiftData

/// SwiftData entity caching session metadata with mtime-based invalidation.
@Model
final class SessionMetaEntity {
    #Unique<SessionMetaEntity>([\.path])

    @Attribute(.unique) var path: String
    var projectDir: String
    var sessionId: String
    var fileMtime: Date
    var fileSize: Int64
    var turnCount: Int
    var duration: Double?
    var preview: String
    var userPreviewsJSON: Data?
    var firstTimestamp: String?
    var lastTimestamp: String?
    var cachedAt: Date

    init(
        path: String,
        projectDir: String,
        sessionId: String,
        fileMtime: Date,
        fileSize: Int64,
        turnCount: Int,
        duration: Double? = nil,
        preview: String,
        userPreviewsJSON: Data? = nil,
        firstTimestamp: String? = nil,
        lastTimestamp: String? = nil,
        cachedAt: Date = Date()
    ) {
        self.path = path
        self.projectDir = projectDir
        self.sessionId = sessionId
        self.fileMtime = fileMtime
        self.fileSize = fileSize
        self.turnCount = turnCount
        self.duration = duration
        self.preview = preview
        self.userPreviewsJSON = userPreviewsJSON
        self.firstTimestamp = firstTimestamp
        self.lastTimestamp = lastTimestamp
        self.cachedAt = cachedAt
    }

    /// Convenience: decode userPreviews from JSON data.
    var userPreviews: [String]? {
        guard let data = userPreviewsJSON else { return nil }
        return try? JSONDecoder().decode([String].self, from: data)
    }

    /// Convert to the value-type SessionMeta model.
    func toSessionMeta() -> SessionMeta {
        SessionMeta(
            path: path,
            projectDir: projectDir,
            sessionId: sessionId,
            fileMtime: fileMtime,
            fileSize: fileSize,
            turnCount: turnCount,
            duration: duration,
            preview: preview,
            userPreviews: userPreviews,
            firstTimestamp: firstTimestamp,
            lastTimestamp: lastTimestamp
        )
    }
}
