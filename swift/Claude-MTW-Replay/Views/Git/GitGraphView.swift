import SwiftUI
struct GitGraphView: View {
    let graph: String
    var body: some View {
        VStack(alignment: .leading) {
            Text("Graph").font(.headline)
            ScrollView { Text(graph).font(.system(.caption2, design: .monospaced)).textSelection(.enabled) }
                .frame(maxHeight: 300)
        }
    }
}
