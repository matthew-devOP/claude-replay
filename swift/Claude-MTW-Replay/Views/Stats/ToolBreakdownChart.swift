import SwiftUI
import Charts
struct ToolBreakdownChart: View {
    let breakdown: [String: Int]
    var sorted: [(String, Int)] { breakdown.sorted { $0.value > $1.value } }
    var body: some View {
        VStack(alignment: .leading) {
            Text("Tool Usage").font(.headline)
            Chart(sorted, id: \.0) { name, count in
                BarMark(x: .value("Count", count), y: .value("Tool", name))
                    .foregroundStyle(Color(hex: "#7aa2f7"))
            }.frame(height: CGFloat(max(sorted.count * 28, 100)))
        }
    }
}
