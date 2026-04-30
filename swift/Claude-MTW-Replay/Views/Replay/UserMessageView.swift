import SwiftUI

struct UserMessageView: View {
    @Environment(AppState.self) private var appState
    let text: String
    @State private var isExpanded = false

    var body: some View {
        // Skip the whole card when there's no user text — turns that are
        // pure tool-result echoes leave `userText` empty after system-tag
        // stripping, and rendering an empty bordered box looked like a
        // bug to users.
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("USER")
                    .font(.caption2)
                    .bold()
                    .foregroundStyle(appState.theme.accent)
                Text(text)
                    .font(.body)
                    .lineLimit(isExpanded ? nil : 10)
                if text.count > 500 || text.components(separatedBy: "\n").count > 10 {
                    Button(isExpanded ? "Show less" : "Show more") { isExpanded.toggle() }
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(8)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(appState.theme.accent)
                    .frame(width: 3)
            }
        }
    }
}
