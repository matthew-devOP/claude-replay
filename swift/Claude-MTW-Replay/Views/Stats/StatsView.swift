import SwiftUI
struct StatsView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = StatsViewModel()
    var body: some View {
        Group {
            if let stats = vm.stats {
                ScrollView { VStack(alignment: .leading, spacing: 16) {
                    StatsOverviewCards(stats: stats)
                    if !stats.toolBreakdown.isEmpty { ToolBreakdownChart(breakdown: stats.toolBreakdown) }
                    if !stats.bashCommands.isEmpty { BashCommandsListView(commands: stats.bashCommands) }
                    if !stats.filesRead.isEmpty || !stats.filesEdited.isEmpty { FilesAccessedView(read: stats.filesRead, edited: stats.filesEdited) }
                    if !stats.agents.isEmpty { AgentsListView(agents: stats.agents) }
                }.padding() }
            } else if vm.isLoading { ProgressView("Computing stats...") }
            else { EmptyStateView(icon: "chart.bar", title: "No Session Selected", subtitle: "Select a session to view stats") }
        }
        .task(id: appState.selectedSessionPath) {
            if let p = appState.selectedSessionPath {
                await vm.loadStats(path: URL(fileURLWithPath: p))
            }
        }
    }
}
