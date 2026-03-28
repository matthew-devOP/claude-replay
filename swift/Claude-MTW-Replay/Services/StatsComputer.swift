import Foundation

enum StatsComputer {
    static func compute(turns: [Turn]) -> SessionStats {
        var textBlocks = 0, thinkingBlocks = 0, toolBlocks = 0, errors = 0
        var toolBreakdown: [String: Int] = [:]
        var bashCommands: [BashCommand] = []
        var filesRead: [String] = []
        var filesEdited: [String] = []
        var agents: [AgentInfo] = []
        var userChars = 0, assistantChars = 0, thinkingChars = 0

        for turn in turns {
            userChars += turn.userText.count
            for block in turn.blocks {
                switch block.kind {
                case .text: textBlocks += 1; assistantChars += block.text.count
                case .thinking: thinkingBlocks += 1; thinkingChars += block.text.count
                case .toolUse: toolBlocks += 1
                }
                if let tc = block.toolCall {
                    toolBreakdown[tc.name, default: 0] += 1
                    if tc.isError { errors += 1 }
                    switch tc.name {
                    case "Bash":
                        if let cmd = tc.input["command"]?.stringValue {
                            bashCommands.append(BashCommand(command: cmd, turnIndex: turn.index, isError: tc.isError))
                        }
                    case "Read", "Grep", "Glob":
                        if let path = tc.input["file_path"]?.stringValue ?? tc.input["path"]?.stringValue {
                            filesRead.append(path)
                        }
                    case "Edit", "Write":
                        if let path = tc.input["file_path"]?.stringValue {
                            filesEdited.append(path)
                        }
                    case "Agent":
                        let name = tc.input["name"]?.stringValue ?? "unnamed"
                        let prompt = tc.input["prompt"]?.stringValue ?? ""
                        agents.append(AgentInfo(name: name, prompt: String(prompt.prefix(200)), mode: tc.input["mode"]?.stringValue, model: tc.input["model"]?.stringValue))
                    default: break
                    }
                }
            }
        }

        var duration: TimeInterval?
        if let first = turns.first?.timestamp?.parseISO8601(),
           let last = turns.last?.timestamp?.parseISO8601() {
            duration = last.timeIntervalSince(first)
        }

        return SessionStats(
            turnCount: turns.count,
            textBlockCount: textBlocks, thinkingBlockCount: thinkingBlocks, toolBlockCount: toolBlocks,
            errorCount: errors, toolBreakdown: toolBreakdown, bashCommands: bashCommands,
            filesRead: Array(Set(filesRead)), filesEdited: Array(Set(filesEdited)),
            agents: agents, duration: duration,
            userCharCount: userChars, assistantCharCount: assistantChars, thinkingCharCount: thinkingChars
        )
    }
}
