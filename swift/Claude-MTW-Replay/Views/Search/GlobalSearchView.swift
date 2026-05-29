import SwiftUI
struct GlobalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var isSearching = false
    var body: some View {
        VStack(spacing: DesignTokens.space12) {
            HStack { TextField("Search across sessions...", text: $query).onSubmit { search() }; Button("Search") { search() }.disabled(query.isEmpty) }
            if isSearching { ProgressView() } else {
                List(results) { r in
                    Button {
                        appState.selectSession(r.sessionPath)
                        dismiss()
                    } label: {
                        SearchResultRowView(result: r)
                    }
                    .buttonStyle(.plain)
                }
            }
            Button("Close") { dismiss() }.keyboardShortcut(.escape, modifiers: [])
        }.padding().frame(width: 600, height: 500)
    }
    private func search() {
        isSearching = true
        results = []
        Task.detached { [query, selectedDir = appState.selectedProjectDirName, accountDir = appState.claudeAccountDir] in
            let found: [SearchResult]
            if let dir = selectedDir {
                found = SearchService.search(query: query, in: dir)
            } else {
                found = SearchService.searchAllProjects(query: query, claudeAccountDir: accountDir)
            }
            await MainActor.run {
                results = found
                isSearching = false
            }
        }
    }
}
