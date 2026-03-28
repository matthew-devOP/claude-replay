import SwiftUI
struct MarkdownTextView: View {
    let markdown: String
    var body: some View {
        Text(LocalizedStringKey(markdown)).textSelection(.enabled)
    }
}
