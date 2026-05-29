import SwiftUI

/// Floating dropdown listing matching `/commands` discovered by
/// `SlashCommandService`. Rendered as an overlay above the chat input
/// while the draft begins with `/` and contains no whitespace.
struct SlashCommandPickerView: View {
    @Environment(AppState.self) private var appState
    let commands: [SlashCommand]
    let filter: String  // text after the leading `/`
    let onPick: (SlashCommand) -> Void

    var filtered: [SlashCommand] {
        if filter.isEmpty { return commands }
        let needle = filter.lowercased()
        return commands.filter { $0.name.lowercased().contains(needle) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if filtered.isEmpty {
                Text("No matching commands")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(DesignTokens.space8)
            } else {
                ForEach(Array(filtered.prefix(8))) { cmd in
                    Button {
                        onPick(cmd)
                    } label: {
                        VStack(alignment: .leading, spacing: DesignTokens.space2) {
                            HStack {
                                Text("/\(cmd.name)")
                                    .font(.system(.body, design: .monospaced))
                                if let d = cmd.description {
                                    Text(d)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(cmd.source.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(DesignTokens.spaceSM)
                    .background(appState.theme.bgHover.opacity(0.5))
                    Divider()
                }
            }
        }
        .appGlass(in: RoundedRectangle(cornerRadius: DesignTokens.cornerMedium))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerMedium))
        .shadow(radius: 6)
        .frame(maxWidth: 360)
    }
}
