import SwiftUI
struct TranscriptTurnView: View {
    let turn: Turn
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Turn \(turn.index)").font(.caption).bold()
            UserMessageView(text: turn.userText)
            ForEach(Array(turn.blocks.enumerated()), id: \.offset) { _, block in
                switch block.kind {
                case .text: AssistantTextView(text: block.text)
                case .thinking: ThinkingBlockView(text: block.text)
                case .toolUse: ToolCallView(block: block)
                }
            }
        }.padding(8).background(Color(hex: "#24253a").opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }
}
