import SwiftUI
struct ThinkingBlockView: View {
    let text: String
    @State private var isExpanded = false
    var body: some View {
        DisclosureGroup("Thinking", isExpanded: $isExpanded) {
            Text(text).font(.body).foregroundStyle(.secondary)
        }
        .padding(8).overlay(alignment: .leading) { Rectangle().fill(Color(hex: "#565f89")).frame(width: 2) }
    }
}
