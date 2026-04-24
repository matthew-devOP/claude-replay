import Foundation

/// A named bookmark pointing to a specific turn in a session.
struct Bookmark: Codable, Identifiable, Hashable, Sendable {
    let id: UUID

    let turn: Int
    let label: String

    init(id: UUID = UUID(), turn: Int, label: String) {
        self.id = id
        self.turn = turn
        self.label = label
    }
}
