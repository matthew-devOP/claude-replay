import SwiftUI
struct ReplayTurnView: View {
    let turn: Turn; let turnNumber: Int; let revealedBlocks: Int; let showThinking: Bool; let showToolCalls: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("Turn \(turnNumber)").font(.caption).bold(); if let ts = turn.timestamp { Text(ts).font(.caption2).foregroundStyle(.secondary) }; Spacer() }
            UserMessageView(text: turn.userText)
            ForEach(Array(turn.blocks.prefix(revealedBlocks).enumerated()), id: \.offset) { _, block in
                switch block.kind {
                case .text: AssistantTextView(text: block.text)
                case .thinking: if showThinking { ThinkingBlockView(text: block.text) }
                case .toolUse: if showToolCalls { ToolCallView(block: block) }
                }
            }
        }.padding(12).background(Color(hex: "#24253a").opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}
