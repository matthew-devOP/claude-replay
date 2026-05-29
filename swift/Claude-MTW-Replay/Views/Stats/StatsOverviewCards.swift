import SwiftUI
struct StatsOverviewCards: View {
    let stats: SessionStats
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: DesignTokens.space12) {
            StatCard(label: "Turns", value: "\(stats.turnCount)")
            StatCard(label: "Duration", value: stats.duration?.formattedDuration() ?? "-")
            StatCard(label: "Errors", value: "\(stats.errorCount)")
            StatCard(label: "Tools Used", value: "\(stats.blockCounts.toolUse)")
        }
    }
}
struct StatCard: View {
    @Environment(AppState.self) private var appState
    let label: String; let value: String
    var body: some View {
        VStack(spacing: DesignTokens.space4) { Text(value).font(.title2).bold(); Text(label).font(.caption).foregroundStyle(.secondary) }
        .frame(maxWidth: .infinity).padding(DesignTokens.space12).background(appState.theme.bgSurface, in: RoundedRectangle(cornerRadius: DesignTokens.cornerMedium))
    }
}
