import SwiftUI

/// Floating dropdown listing matching `/commands` discovered by
/// `SlashCommandService`. Rendered as an overlay above the chat input
/// while the draft begins with `/` and contains no whitespace.
struct SlashCommandPickerView: View {
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
                    .padding(8)
            } else {
                ForEach(Array(filtered.prefix(8))) { cmd in
                    Button {
                        onPick(cmd)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
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
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    Divider()
                }
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 6)
        .frame(maxWidth: 360)
    }
}
