import SwiftUI
struct GlobalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var isSearching = false
    var body: some View {
        VStack(spacing: 12) {
            HStack { TextField("Search across sessions...", text: $query).onSubmit { search() }; Button("Search") { search() }.disabled(query.isEmpty) }
            if isSearching { ProgressView() } else {
                List(results) { r in SearchResultRowView(result: r) }
            }
            Button("Close") { dismiss() }.keyboardShortcut(.escape, modifiers: [])
        }.padding().frame(width: 600, height: 500)
    }
    private func search() {
        guard let dir = appState.selectedProjectDirName else { return }
        isSearching = true
        results = SearchService.search(query: query, in: dir)
        isSearching = false
    }
}
