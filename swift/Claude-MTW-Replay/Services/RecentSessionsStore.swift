import Foundation

/// Persists a most-recent-first list of session file URLs the user has opened.
///
/// This is intentionally separate from `StatusItemController`'s
/// `recentSessions` key — that store backs the menu-bar status item submenu
/// and is keyed by display name. This one is keyed by full URL/path and is
/// used by the `Open Recent` File menu and the drag-and-drop importer, per
/// P3.1 / P3.2 of `docs/IMPROVEMENTS_SWIFT.md`.
@MainActor
final class RecentSessionsStore {
    static let shared = RecentSessionsStore()

    private let key = "recentSessionURLs"
    private let maxItems = 10

    struct Entry: Codable, Hashable {
        let path: String
        let displayName: String
        let openedAt: Date
    }

    func recents() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data) else {
            return []
        }
        return decoded
    }

    func add(path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let url = URL(fileURLWithPath: trimmed)
        let entry = Entry(path: trimmed, displayName: url.lastPathComponent, openedAt: .now)
        var current = recents()
        current.removeAll { $0.path == trimmed }
        current.insert(entry, at: 0)
        if current.count > maxItems {
            current = Array(current.prefix(maxItems))
        }
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
