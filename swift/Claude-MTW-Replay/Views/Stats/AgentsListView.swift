import SwiftUI
struct AgentsListView: View {
    @Environment(AppState.self) private var appState
    let agents: [SessionStats.AgentInfo]
    var body: some View {
        VStack(alignment: .leading) {
            Text("Sub-Agents (\(agents.count))").font(.headline)
            ForEach(Array(agents.enumerated()), id: \.offset) { _, agent in
                VStack(alignment: .leading, spacing: DesignTokens.space2) {
                    HStack {
                        Text(agent.name).bold()
                        if let t = agent.subagentType, !t.isEmpty { Text(t).font(.caption).foregroundStyle(.secondary) }
                        if let m = agent.model { Text(m).font(.caption).foregroundStyle(.secondary) }
                    }
                    Text(agent.prompt).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                }.padding(DesignTokens.space6).background(appState.theme.bgSurface, in: RoundedRectangle(cornerRadius: DesignTokens.cornerSmall))
            }
        }
    }
}

struct TeamsListView: View {
    @Environment(AppState.self) private var appState
    let teams: [SessionStats.TeamOp]
    var body: some View {
        VStack(alignment: .leading) {
            Text("Teams (\(teams.count))").font(.headline)
            ForEach(teams) { team in
                HStack(spacing: DesignTokens.space6) {
                    Image(systemName: team.action == "TeamDelete" ? "person.2.slash" : "person.2")
                        .foregroundStyle(.secondary)
                    Text(team.action).bold()
                    if let n = team.teamName, !n.isEmpty { Text(n).font(.caption).foregroundStyle(.secondary) }
                }.padding(DesignTokens.space6).background(appState.theme.bgSurface, in: RoundedRectangle(cornerRadius: DesignTokens.cornerSmall))
            }
        }
    }
}
