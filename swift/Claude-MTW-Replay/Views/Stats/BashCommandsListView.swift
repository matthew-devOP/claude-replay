import SwiftUI
struct BashCommandsListView: View {
    let commands: [SessionStats.BashCommand]
    var body: some View {
        VStack(alignment: .leading) {
            Text("Bash Commands (\(commands.count))").font(.headline)
            ForEach(Array(commands.enumerated()), id: \.offset) { _, cmd in
                HStack {
                    if cmd.isError { Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red).font(.caption) }
                    Text(cmd.command).font(.system(.caption, design: .monospaced)).lineLimit(2)
                    Spacer()
                    Text("Turn \(cmd.turnIndex)").font(.caption2).foregroundStyle(.secondary)
                }.padding(DesignTokens.space4)
            }
        }
    }
}
