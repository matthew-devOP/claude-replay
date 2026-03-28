import SwiftUI
struct StatsOverviewCards: View {
    let stats: SessionStats
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
            StatCard(label: "Turns", value: "\(stats.turnCount)")
            StatCard(label: "Duration", value: stats.duration?.formattedDuration() ?? "-")
            StatCard(label: "Errors", value: "\(stats.errorCount)")
            StatCard(label: "Tools Used", value: "\(stats.toolBlockCount)")
        }
    }
}
struct StatCard: View {
    let label: String; let value: String
    var body: some View {
        VStack(spacing: 4) { Text(value).font(.title2).bold(); Text(label).font(.caption).foregroundStyle(.secondary) }
        .frame(maxWidth: .infinity).padding(12).background(Color(hex: "#24253a"), in: RoundedRectangle(cornerRadius: 8))
    }
}
