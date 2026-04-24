import SwiftUI
import Charts
struct ToolBreakdownChart: View {
    @Environment(AppState.self) private var appState
    let breakdown: [String: Int]
    var sorted: [(String, Int)] { breakdown.sorted { $0.value > $1.value } }

    private var palette: [Color] {
        [
            appState.theme.blue,
            appState.theme.green,
            appState.theme.orange,
            appState.theme.accent,
            appState.theme.cyan,
            appState.theme.red,
        ]
    }

    private func color(for index: Int) -> Color {
        palette[index % palette.count]
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Tool Usage").font(.headline)
            Chart(Array(sorted.enumerated()), id: \.element.0) { index, item in
                let (name, count) = item
                BarMark(x: .value("Count", count), y: .value("Tool", name))
                    .foregroundStyle(color(for: index))
            }.frame(height: CGFloat(max(sorted.count * 28, 100)))
        }
    }
}
