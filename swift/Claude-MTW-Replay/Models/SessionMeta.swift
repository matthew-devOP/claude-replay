import Foundation

/// Metadata for a single session JSONL file.
struct SessionMeta: Codable, Identifiable, Hashable, Sendable {
    var id: String { path }

    let path: String
    let projectDir: String
    let sessionId: String
    let fileMtime: Date
    let fileSize: Int64
    let turnCount: Int
    let duration: TimeInterval?
    let preview: String
    let userPreviews: [String]?
    let firstTimestamp: String?
    let lastTimestamp: String?

    init(
        path: String,
        projectDir: String,
        sessionId: String,
        fileMtime: Date,
        fileSize: Int64,
        turnCount: Int,
        duration: TimeInterval? = nil,
        preview: String,
        userPreviews: [String]? = nil,
        firstTimestamp: String? = nil,
        lastTimestamp: String? = nil
    ) {
        self.path = path
        self.projectDir = projectDir
        self.sessionId = sessionId
        self.fileMtime = fileMtime
        self.fileSize = fileSize
        self.turnCount = turnCount
        self.duration = duration
        self.preview = preview
        self.userPreviews = userPreviews
        self.firstTimestamp = firstTimestamp
        self.lastTimestamp = lastTimestamp
    }
}
