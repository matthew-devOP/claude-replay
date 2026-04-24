import SwiftUI
struct ReplayTurnView: View {
    @Environment(AppState.self) private var appState
    let turn: Turn; let turnNumber: Int; let revealedBlocks: Int; let showThinking: Bool; let showToolCalls: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("Turn \(turnNumber)").font(.caption).bold(); if let ts = turn.timestamp { Text(ts).font(.caption2).foregroundStyle(.secondary) }; Spacer() }
            UserMessageView(text: turn.userText)
            let revealed = Array(turn.blocks.prefix(revealedBlocks))
            let grouped = groupBlocks(revealed)
            ForEach(Array(grouped.enumerated()), id: \.offset) { _, group in
                switch group {
                case .single(let block):
                    switch block.kind {
                    case .text: AssistantTextView(text: block.text)
                    case .thinking: if showThinking { ThinkingBlockView(text: block.text) }
                    case .toolUse: if showToolCalls { ToolCallView(block: block) }
                    }
                case .toolGroup(let blocks):
                    if showToolCalls {
                        CollapsedToolGroupView(blocks: blocks)
                    }
                }
            }
        }.padding(12).background(appState.theme.bgSurface.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private enum BlockGroup {
        case single(AssistantBlock)
        case toolGroup([AssistantBlock])
    }

    private func groupBlocks(_ blocks: [AssistantBlock]) -> [BlockGroup] {
        var result: [BlockGroup] = []
        var toolRun: [AssistantBlock] = []
        for block in blocks {
            if block.kind == .toolUse {
                toolRun.append(block)
            } else {
                if toolRun.count >= 5 {
                    result.append(.toolGroup(toolRun))
                } else {
                    for b in toolRun { result.append(.single(b)) }
                }
                toolRun = []
                result.append(.single(block))
            }
        }
        if toolRun.count >= 5 {
            result.append(.toolGroup(toolRun))
        } else {
            for b in toolRun { result.append(.single(b)) }
        }
        return result
    }
}

private struct CollapsedToolGroupView: View {
    @Environment(AppState.self) private var appState
    let blocks: [AssistantBlock]
    @State private var isExpanded = false
    var body: some View {
        let uniqueNames = Array(Set(blocks.compactMap { $0.toolCall?.name })).sorted()
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(blocks.enumerated()), id: \.element.id) { _, block in
                    ToolCallView(block: block)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundStyle(.secondary)
                Text("\(blocks.count) tool calls")
                    .font(.caption).bold()
                Text("(\(uniqueNames.joined(separator: ", ")))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(6)
        .background(appState.theme.bgSurface.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
    }
}
