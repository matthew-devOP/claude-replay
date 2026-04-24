import SwiftUI
struct BookmarkBarView: View {
    @Environment(AppState.self) private var appState
    let bookmarks: [Bookmark]; let totalTurns: Int
    let onTap: (Int) -> Void
    var body: some View {
        GeometryReader { geo in
            ForEach(bookmarks) { bm in
                let x = totalTurns > 0 ? geo.size.width * Double(bm.turn) / Double(totalTurns) : 0
                Circle().fill(appState.theme.orange).frame(width: 8, height: 8).position(x: x, y: 3)
                    .onTapGesture { onTap(bm.turn) }
                    .help(bm.label)
            }
        }.frame(height: 6)
    }
}
