import SwiftUI
struct TranscriptSearchBar: View {
    @Environment(AppState.self) private var appState
    @Binding var searchText: String; let matchCount: Int; let onNext: () -> Void; let onPrev: () -> Void
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search transcript...", text: $searchText)
            if !searchText.isEmpty {
                Text("\(matchCount) matches").font(.caption).foregroundStyle(.secondary)
                Button { onPrev() } label: { Image(systemName: "chevron.up") }
                Button { onNext() } label: { Image(systemName: "chevron.down") }
                Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
            }
        }.padding(8).background(appState.theme.bgSurface)
    }
}
