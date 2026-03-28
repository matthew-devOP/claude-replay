import SwiftUI
struct SearchResultRowView: View {
    let result: SearchResult
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Text("Turn \(result.turnIndex)").font(.caption).bold(); Text(result.role).font(.caption2).padding(.horizontal, 4).background(Color(hex: "#bb9af7").opacity(0.2), in: Capsule()) }
            Text(result.matchText).font(.body).lineLimit(3)
        }.padding(.vertical, 4)
    }
}
