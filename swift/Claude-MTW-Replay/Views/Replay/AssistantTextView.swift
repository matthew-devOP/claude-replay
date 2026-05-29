import SwiftUI
struct AssistantTextView: View {
    @Environment(AppState.self) private var appState
    let text: String
    @State private var isExpanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.space4) {
            Text("ASSISTANT").font(.caption2).bold().foregroundStyle(appState.theme.cyan)
            MarkdownTextView(markdown: text).lineLimit(isExpanded ? nil : 15)
            if text.count > 500 || text.components(separatedBy: "\n").count > 15 {
                Button(isExpanded ? "Show less" : "Show more") { isExpanded.toggle() }.font(.caption).foregroundStyle(appState.theme.accent)
            }
        }.padding(DesignTokens.space8).overlay(alignment: .leading) { Rectangle().fill(appState.theme.cyan).frame(width: 3) }
    }
}
