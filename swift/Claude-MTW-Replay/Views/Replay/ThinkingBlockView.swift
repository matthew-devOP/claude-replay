import SwiftUI
struct ThinkingBlockView: View {
    @Environment(AppState.self) private var appState
    let text: String
    @State private var isExpanded = false
    var body: some View {
        DisclosureGroup("Thinking", isExpanded: $isExpanded) {
            Text(text).font(.body).foregroundStyle(.secondary)
        }
        .padding(8).overlay(alignment: .leading) { Rectangle().fill(appState.theme.textDim).frame(width: 2) }
    }
}
