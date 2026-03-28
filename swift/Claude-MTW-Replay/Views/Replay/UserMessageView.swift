import SwiftUI
struct UserMessageView: View {
    let text: String
    @State private var isExpanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("USER").font(.caption2).bold().foregroundStyle(Color(hex: "#bb9af7"))
            Text(text).font(.body).lineLimit(isExpanded ? nil : 10)
            if text.components(separatedBy: "\n").count > 10 {
                Button(isExpanded ? "Show less" : "Show more") { isExpanded.toggle() }.font(.caption).foregroundStyle(.accent)
            }
        }.padding(8).overlay(alignment: .leading) { Rectangle().fill(Color(hex: "#bb9af7")).frame(width: 3) }
    }
}
