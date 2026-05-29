import SwiftUI
struct TranscriptTurnView: View {
    @Environment(AppState.self) private var appState
    let turn: Turn
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.space8) {
            Text("Turn \(turn.index)").font(.caption).bold()
            UserMessageView(text: turn.userText)
            ForEach(Array(turn.blocks.enumerated()), id: \.offset) { _, block in
                switch block.kind {
                case .text: AssistantTextView(text: block.text)
                case .thinking: ThinkingBlockView(text: block.text)
                case .toolUse: ToolCallView(block: block)
                }
            }
        }.padding(DesignTokens.space8).background(appState.theme.bgSurface.opacity(0.3), in: RoundedRectangle(cornerRadius: DesignTokens.cornerMedium))
    }
}
