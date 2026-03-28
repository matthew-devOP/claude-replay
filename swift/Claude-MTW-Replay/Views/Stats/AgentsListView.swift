import SwiftUI
struct AgentsListView: View {
    let agents: [AgentInfo]
    var body: some View {
        VStack(alignment: .leading) {
            Text("Sub-Agents (\(agents.count))").font(.headline)
            ForEach(Array(agents.enumerated()), id: \.offset) { _, agent in
                VStack(alignment: .leading, spacing: 2) {
                    HStack { Text(agent.name).bold(); if let m = agent.model { Text(m).font(.caption).foregroundStyle(.secondary) } }
                    Text(agent.prompt).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                }.padding(6).background(Color(hex: "#24253a"), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}
