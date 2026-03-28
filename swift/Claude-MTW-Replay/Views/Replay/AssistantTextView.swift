import SwiftUI
struct AssistantTextView: View {
    let text: String
    @State private var isExpanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ASSISTANT").font(.caption2).bold().foregroundStyle(Color(hex: "#7dcfff"))
            Text(text).font(.body).lineLimit(isExpanded ? nil : 15)
            if text.components(separatedBy: "\n").count > 15 {
                Button(isExpanded ? "Show less" : "Show more") { isExpanded.toggle() }.font(.caption).foregroundStyle(.accent)
            }
        }.padding(8).overlay(alignment: .leading) { Rectangle().fill(Color(hex: "#7dcfff")).frame(width: 3) }
    }
}
