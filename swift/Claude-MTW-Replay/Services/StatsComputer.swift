import Foundation

enum StatsComputer {
    static func compute(turns: [Turn]) -> SessionStats {
        var textBlocks = 0, thinkingBlocks = 0, toolBlocks = 0, errors = 0
        var toolBreakdown: [String: Int] = [:]
        var bashCommands: [SessionStats.BashCommand] = []
        var filesRead: [String] = []
        var filesEdited: [String] = []
        var agents: [SessionStats.AgentInfo] = []
        var teams: [SessionStats.TeamOp] = []
        var userChars = 0, assistantChars = 0, thinkingChars = 0
        var userMessages: [SessionStats.UserMessage] = []
        var assistantTexts: [SessionStats.AssistantText] = []
        var longestTurnIndex = 0, longestTurnCount = 0

        for turn in turns {
            userChars += turn.userText.count
            if !turn.userText.isEmpty {
                userMessages.append(SessionStats.UserMessage(text: String(turn.userText.prefix(200)), turn: turn.index))
            }
            let blockCountForTurn = turn.blocks.count
            if blockCountForTurn > longestTurnCount {
                longestTurnCount = blockCountForTurn
                longestTurnIndex = turn.index
            }
            for block in turn.blocks {
                switch block.kind {
                case .text:
                    textBlocks += 1
                    assistantChars += block.text.count
                    if !block.text.isEmpty {
                        assistantTexts.append(SessionStats.AssistantText(text: String(block.text.prefix(200)), turn: turn.index))
                    }
                case .thinking: thinkingBlocks += 1; thinkingChars += block.text.count
                case .toolUse: toolBlocks += 1
                }
                if let tc = block.toolCall {
                    toolBreakdown[tc.name, default: 0] += 1
                    if tc.isError { errors += 1 }
                    switch tc.name {
                    case "Bash":
                        if let cmd = tc.input["command"]?.stringValue {
                            bashCommands.append(SessionStats.BashCommand(turnIndex: turn.index, command: cmd, isError: tc.isError))
                        }
                    case "Read":
                        if let path = tc.input["file_path"]?.stringValue ?? tc.input["path"]?.stringValue {
                            filesRead.append(path)
                        }
                    case "Edit", "Write":
                        if let path = tc.input["file_path"]?.stringValue {
                            filesEdited.append(path)
                        }
                    case "Agent":
                        // Web reads `description` (the Agent tool's human label),
                        // not `name` — fall back to subagent_type, then "unnamed".
                        let subagentType = tc.input["subagent_type"]?.stringValue
                        let name = tc.input["description"]?.stringValue
                            ?? subagentType
                            ?? "unnamed"
                        let prompt = tc.input["prompt"]?.stringValue ?? ""
                        agents.append(SessionStats.AgentInfo(turnIndex: turn.index, name: name, subagentType: subagentType, model: tc.input["model"]?.stringValue, prompt: String(prompt.prefix(200)), mode: tc.input["mode"]?.stringValue))
                    case "TeamCreate", "TeamDelete":
                        teams.append(SessionStats.TeamOp(turnIndex: turn.index, action: tc.name, teamName: tc.input["team_name"]?.stringValue ?? tc.input["name"]?.stringValue))
                    default: break
                    }
                }
            }
        }

        var duration: TimeInterval?
        if let first = turns.first?.timestamp?.parseISO8601() {
            var lastDate = first
            for turn in turns {
                if let ts = turn.timestamp?.parseISO8601(), ts > lastDate { lastDate = ts }
                for block in turn.blocks {
                    if let ts = block.timestamp?.parseISO8601(), ts > lastDate { lastDate = ts }
                    if let ts = block.toolCall?.resultTimestamp?.parseISO8601(), ts > lastDate { lastDate = ts }
                }
            }
            duration = lastDate.timeIntervalSince(first)
        }

        let totalBlocks = textBlocks + thinkingBlocks + toolBlocks
        let avgBlocksPerTurn = turns.isEmpty ? 0.0 : Double(totalBlocks) / Double(turns.count)
        let longestTurn: SessionStats.LongestTurn? = longestTurnCount > 0
            ? SessionStats.LongestTurn(index: longestTurnIndex, blockCount: longestTurnCount)
            : nil

        return SessionStats(
            turnCount: turns.count,
            blockCounts: SessionStats.BlockCounts(text: textBlocks, thinking: thinkingBlocks, toolUse: toolBlocks),
            errorCount: errors,
            toolBreakdown: toolBreakdown,
            bashCommands: bashCommands,
            filesRead: Array(Set(filesRead)),
            filesEdited: Array(Set(filesEdited)),
            agents: agents,
            duration: duration,
            charCounts: SessionStats.CharCounts(user: userChars, assistant: assistantChars, thinking: thinkingChars),
            avgBlocksPerTurn: avgBlocksPerTurn,
            longestTurn: longestTurn,
            userMessages: userMessages,
            assistantTexts: assistantTexts,
            teams: teams
        )
    }
}
