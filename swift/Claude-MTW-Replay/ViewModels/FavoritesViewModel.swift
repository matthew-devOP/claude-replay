import Foundation

@Observable
final class FavoritesViewModel {
    var favorites: [String] = [] // paths

    @MainActor
    func loadFavorites() {
        let entities = DataStore.shared.getFavorites()
        favorites = entities.map(\.path)
    }

    func isFavorite(_ path: String) -> Bool { favorites.contains(path) }

    @MainActor
    func addFavorite(path: String, sessionId: String, preview: String = "", projectDir: String = "") {
        guard !isFavorite(path) else { return }
        let entity = FavoriteEntity(path: path, sessionId: sessionId, preview: preview, projectDir: projectDir)
        DataStore.shared.addFavorite(entity)
        favorites.append(path)
    }

    @MainActor
    func removeFavorite(path: String) {
        DataStore.shared.removeFavorite(path: path)
        favorites.removeAll { $0 == path }
    }

    @MainActor
    func toggle(path: String, sessionId: String, preview: String = "", projectDir: String = "") {
        if isFavorite(path) {
            removeFavorite(path: path)
        } else {
            addFavorite(path: path, sessionId: sessionId, preview: preview, projectDir: projectDir)
        }
    }
}
