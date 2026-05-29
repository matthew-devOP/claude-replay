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
    let avgBlocksPerTurn: Double
    let longestTurn: LongestTurn?
    let userMessages: [UserMessage]
    let assistantTexts: [AssistantText]
    let teams: [TeamOp]

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
        let thinking: Int

        var total: Int { user + assistant + thinking }

        enum CodingKeys: String, CodingKey {
            case user
            case assistant
            case thinking
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

    struct LongestTurn: Codable, Hashable, Sendable {
        let index: Int
        let blockCount: Int
    }

    struct UserMessage: Codable, Hashable, Sendable {
        let text: String
        let turn: Int
    }

    struct AssistantText: Codable, Hashable, Sendable {
        let text: String
        let turn: Int
    }

    struct AgentInfo: Codable, Identifiable, Hashable, Sendable {
        var id: String { "\(turnIndex)-\(name)" }

        let turnIndex: Int
        /// Human label for the spawned agent. Mirrors the web stats, which use
        /// the Agent tool's `description` input (editor-server.mjs:811), NOT a
        /// `name` field — Claude's Agent tool has no `name` input, so the old
        /// `input["name"]` read always fell back to "unnamed".
        let name: String
        let subagentType: String?
        let model: String?
        let prompt: String
        let mode: String?

        enum CodingKeys: String, CodingKey {
            case turnIndex = "turn_index"
            case name
            case subagentType = "subagent_type"
            case model
            case prompt
            case mode
        }
    }

    /// A team lifecycle operation (TeamCreate / TeamDelete). Mirrors the web
    /// stats `teams` collection (editor-server.mjs:821-827).
    struct TeamOp: Codable, Identifiable, Hashable, Sendable {
        var id: String { "\(turnIndex)-\(action)" }

        let turnIndex: Int
        let action: String
        let teamName: String?

        enum CodingKeys: String, CodingKey {
            case turnIndex = "turn_index"
            case action
            case teamName = "team_name"
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
        case avgBlocksPerTurn = "avg_blocks_per_turn"
        case longestTurn = "longest_turn"
        case userMessages = "user_messages"
        case assistantTexts = "assistant_texts"
        case teams
    }
}
