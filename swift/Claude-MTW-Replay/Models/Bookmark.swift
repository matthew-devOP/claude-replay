import Foundation

/// A named bookmark pointing to a specific turn in a session.
struct Bookmark: Codable, Identifiable, Hashable, Sendable {
    var id: Int { turn }

    let turn: Int
    let label: String

    init(turn: Int, label: String) {
        self.turn = turn
        self.label = label
    }
}
