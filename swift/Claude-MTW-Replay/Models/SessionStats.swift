import Foundation

/// Computed statistics for a parsed session.
struct SessionStats: Codable, Hashable, Sendable {
    let turnCount: Int
    let blockCounts: BlockCounts
    let errorCount: Int
    let toolBreakdown: [String: Int]
    let bashCommands: [BashCommand]
    let filesRead: [String]
    let filesEdited: [String]
    let agents: [AgentInfo]
    let duration: TimeInterval?
    let charCounts: CharCounts

    // MARK: - Nested types

    struct BlockCounts: Codable, Hashable, Sendable {
        let text: Int
        let thinking: Int
        let toolUse: Int

        var total: Int { text + thinking + toolUse }

        enum CodingKeys: String, CodingKey {
            case text
            case thinking
            case toolUse = "tool_use"
        }
    }

    struct CharCounts: Codable, Hashable, Sendable {
        let user: Int
        let assistant: Int
        let toolResult: Int

        var total: Int { user + assistant + toolResult }

        enum CodingKeys: String, CodingKey {
            case user
            case assistant
            case toolResult = "tool_result"
        }
    }

    struct BashCommand: Codable, Identifiable, Hashable, Sendable {
        var id: String { "\(turnIndex)-\(command.prefix(80))" }

        let turnIndex: Int
        let command: String
        let isError: Bool

        enum CodingKeys: String, CodingKey {
            case turnIndex = "turn_index"
            case command
            case isError = "is_error"
        }
    }

    struct AgentInfo: Codable, Identifiable, Hashable, Sendable {
        var id: String { "\(turnIndex)-\(toolUseId)" }

        let turnIndex: Int
        let toolUseId: String
        let model: String?
        let prompt: String?

        enum CodingKeys: String, CodingKey {
            case turnIndex = "turn_index"
            case toolUseId = "tool_use_id"
            case model
            case prompt
        }
    }

    enum CodingKeys: String, CodingKey {
        case turnCount = "turn_count"
        case blockCounts = "block_counts"
        case errorCount = "error_count"
        case toolBreakdown = "tool_breakdown"
        case bashCommands = "bash_commands"
        case filesRead = "files_read"
        case filesEdited = "files_edited"
        case agents
        case duration
        case charCounts = "char_counts"
    }
}
