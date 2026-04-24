import Foundation

/// A single match from searching across sessions.
struct SearchResult: Codable, Identifiable, Hashable, Sendable {
    let id: UUID

    let projectName: String
    let sessionPath: String
    let turnIndex: Int
    let matchText: String
    let role: String
    let context: String

    init(
        id: UUID = UUID(),
        projectName: String,
        sessionPath: String,
        turnIndex: Int,
        matchText: String,
        role: String,
        context: String
    ) {
        self.id = id
        self.projectName = projectName
        self.sessionPath = sessionPath
        self.turnIndex = turnIndex
        self.matchText = matchText
        self.role = role
        self.context = context
    }
}
