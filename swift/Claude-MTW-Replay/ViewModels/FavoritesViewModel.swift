import Foundation

@Observable
final class FavoritesViewModel {
    var favorites: [String] = [] // paths

    func isFavorite(_ path: String) -> Bool { favorites.contains(path) }
    func toggle(_ path: String) {
        if favorites.contains(path) { favorites.removeAll { $0 == path } }
        else { favorites.append(path) }
    }
}
