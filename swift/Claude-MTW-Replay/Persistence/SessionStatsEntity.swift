import Foundation
import SwiftData

/// SwiftData entity caching computed session statistics as a JSON blob.
@Model
final class SessionStatsEntity {
    #Unique<SessionStatsEntity>([\.path])

    @Attribute(.unique) var path: String
    var fileMtime: Date
    var statsJSON: Data
    var cachedAt: Date

    init(
        path: String,
        fileMtime: Date,
        statsJSON: Data,
        cachedAt: Date = Date()
    ) {
        self.path = path
        self.fileMtime = fileMtime
        self.statsJSON = statsJSON
        self.cachedAt = cachedAt
    }

    /// Decode the cached stats JSON into a SessionStats value.
    func toSessionStats() -> SessionStats? {
        try? JSONDecoder().decode(SessionStats.self, from: statsJSON)
    }

    /// Create an entity from a SessionStats value.
    static func from(
        path: String,
        fileMtime: Date,
        stats: SessionStats
    ) -> SessionStatsEntity? {
        guard let data = try? JSONEncoder().encode(stats) else { return nil }
        return SessionStatsEntity(
            path: path,
            fileMtime: fileMtime,
            statsJSON: data
        )
    }
}
