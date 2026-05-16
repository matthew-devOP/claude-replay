import SwiftUI

struct FavoritesSectionView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Section("Favorites") {
            if appState.favoritesVM.favorites.isEmpty {
                Text("No favorites yet")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(appState.favoritesVM.favorites, id: \.self) { path in
                    Button {
                        appState.selectSession(path)
                    } label: {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                            Text(displayName(for: path))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Remove from Favorites", role: .destructive) {
                            appState.favoritesVM.removeFavorite(path: path)
                        }
                    }
                }
            }
        }
        .task {
            appState.favoritesVM.loadFavorites()
        }
    }

    private func displayName(for path: String) -> String {
        let last = (path as NSString).lastPathComponent
        let trimmed = last.hasSuffix(".jsonl") ? String(last.dropLast(".jsonl".count)) : last
        if trimmed.count <= 24 { return trimmed }
        let prefix = trimmed.prefix(24)
        return String(prefix) + "…"
    }
}
