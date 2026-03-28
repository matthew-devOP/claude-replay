import Foundation

/// Represents a project directory containing one or more sessions.
struct Project: Codable, Identifiable, Hashable, Sendable {
    var id: String { dirName }

    let source: TranscriptFormat
    let name: String
    let path: String
    let dirName: String
    let sessionCount: Int
    let lastActivity: Date?
    let gitBranch: String?

    init(
        source: TranscriptFormat,
        name: String,
        path: String,
        dirName: String,
        sessionCount: Int,
        lastActivity: Date? = nil,
        gitBranch: String? = nil
    ) {
        self.source = source
        self.name = name
        self.path = path
        self.dirName = dirName
        self.sessionCount = sessionCount
        self.lastActivity = lastActivity
        self.gitBranch = gitBranch
    }
}
