import SwiftUI
struct FavoritesSectionView: View {
    @Environment(AppState.self) private var appState
    var body: some View {
        Section("Favorites") {
            Text("No favorites yet").foregroundStyle(.secondary).font(.caption)
        }
    }
}
