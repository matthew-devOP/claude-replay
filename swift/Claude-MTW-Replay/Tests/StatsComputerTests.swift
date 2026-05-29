import XCTest
@testable import Claude_MTW_Replay

/// Unit tests for `StatsComputer.compute(turns:)`.
///
/// The fixture mirrors a small but representative session covering every
/// branch in `StatsComputer`: text/thinking/tool_use blocks, Bash, Read,
/// Write, Edit, and Agent tool calls, an error result, plus timestamps
/// at the first and last turns so duration is non-nil.
final class StatsComputerTests: XCTestCase {

    // MARK: - Fixture

    /// Build a deterministic small session of 4 turns covering each
    /// supported block kind and the tool names StatsComputer special-cases.
    private func buildFixtureTurns() -> [Turn] {
        // Turn 0 — user only with a text reply
        let t0 = Turn(
            index: 0,
            userText: "hello",
            blocks: [
                AssistantBlock(kind: .text, text: "Hi, ready to help."),
            ],
            timestamp: "2025-01-01T10:00:00Z"
        )

        // Turn 1 — thinking + Bash tool_use (success)
        let bashCall = ToolCall(
            toolUseId: "tu_bash_1",
            name: "Bash",
            input: ["command": AnyCodable("ls -la")]
        )
        let t1 = Turn(
            index: 1,
            userText: "list files",
            blocks: [
                AssistantBlock(kind: .thinking, text: "let me think"),
                AssistantBlock(
                    kind: .toolUse,
                    text: "",
                    toolCall: bashCall
                ),
            ],
            timestamp: "2025-01-01T10:00:10Z"
        )

        // Turn 2 — Read + Write + Edit tool_use
        let readCall = ToolCall(
            toolUseId: "tu_read_1",
            name: "Read",
            input: ["file_path": AnyCodable("/tmp/a.txt")]
        )
        let writeCall = ToolCall(
            toolUseId: "tu_write_1",
            name: "Write",
            input: [
                "file_path": AnyCodable("/tmp/b.txt"),
                "content": AnyCodable("hello"),
            ]
        )
        let editCall = ToolCall(
            toolUseId: "tu_edit_1",
            name: "Edit",
            input: [
                "file_path": AnyCodable("/tmp/c.txt"),
                "old_string": AnyCodable("foo"),
                "new_string": AnyCodable("bar"),
            ]
        )
        let t2 = Turn(
            index: 2,
            userText: "do file work",
            blocks: [
                AssistantBlock(kind: .toolUse, text: "", toolCall: readCall),
                AssistantBlock(kind: .toolUse, text: "", toolCall: writeCall),
                AssistantBlock(kind: .toolUse, text: "", toolCall: editCall),
                AssistantBlock(kind: .text, text: "done"),
            ],
            timestamp: "2025-01-01T10:00:20Z"
        )

        // Turn 3 — Agent tool_use + Bash error
        let agentCall = ToolCall(
            toolUseId: "tu_agent_1",
            name: "Agent",
            input: [
                "description": AnyCodable("research"),
                "subagent_type": AnyCodable("Explore"),
                "prompt": AnyCodable("dig deeper"),
                "model": AnyCodable("opus"),
                "mode": AnyCodable("oneshot"),
            ]
        )
        let bashErr = ToolCall(
            toolUseId: "tu_bash_2",
            name: "Bash",
            input: ["command": AnyCodable("false")],
            isError: true
        )
        let t3 = Turn(
            index: 3,
            userText: "fan out",
            blocks: [
                AssistantBlock(kind: .toolUse, text: "", toolCall: agentCall),
                AssistantBlock(kind: .toolUse, text: "", toolCall: bashErr),
            ],
            timestamp: "2025-01-01T10:01:00Z"
        )

        return [t0, t1, t2, t3]
    }

    // MARK: - Tests

    func testTurnCountMatchesInput() {
        let stats = StatsComputer.compute(turns: buildFixtureTurns())
        XCTAssertEqual(stats.turnCount, 4)
    }

    func testBlockCountsAreAccurate() {
        let stats = StatsComputer.compute(turns: buildFixtureTurns())
        // text: turn0 + turn2-final = 2; thinking: turn1 = 1; tool_use: 1+3+2 = 6
        XCTAssertEqual(stats.blockCounts.text, 2)
        XCTAssertEqual(stats.blockCounts.thinking, 1)
        XCTAssertEqual(stats.blockCounts.toolUse, 6)
    }

    func testToolBreakdownPopulatedPerName() {
        let stats = StatsComputer.compute(turns: buildFixtureTurns())
        XCTAssertEqual(stats.toolBreakdown["Bash"], 2)
        XCTAssertEqual(stats.toolBreakdown["Read"], 1)
        XCTAssertEqual(stats.toolBreakdown["Write"], 1)
        XCTAssertEqual(stats.toolBreakdown["Edit"], 1)
        XCTAssertEqual(stats.toolBreakdown["Agent"], 1)
    }

    func testBashCommandsExtractedWithErrors() {
        let stats = StatsComputer.compute(turns: buildFixtureTurns())
        XCTAssertEqual(stats.bashCommands.count, 2)
        XCTAssertEqual(stats.bashCommands[0].command, "ls -la")
        XCTAssertFalse(stats.bashCommands[0].isError)
        XCTAssertEqual(stats.bashCommands[1].command, "false")
        XCTAssertTrue(stats.bashCommands[1].isError)
        XCTAssertEqual(stats.errorCount, 1)
    }

    func testFilesReadAndEditedExtracted() {
        let stats = StatsComputer.compute(turns: buildFixtureTurns())
        XCTAssertEqual(Set(stats.filesRead), Set(["/tmp/a.txt"]))
        XCTAssertEqual(Set(stats.filesEdited), Set(["/tmp/b.txt", "/tmp/c.txt"]))
    }

    func testAgentCountAndMetadata() {
        let stats = StatsComputer.compute(turns: buildFixtureTurns())
        XCTAssertEqual(stats.agents.count, 1)
        XCTAssertEqual(stats.agents[0].name, "research")
        XCTAssertEqual(stats.agents[0].subagentType, "Explore")
        XCTAssertEqual(stats.agents[0].model, "opus")
        XCTAssertEqual(stats.agents[0].mode, "oneshot")
        XCTAssertEqual(stats.agents[0].prompt, "dig deeper")
        XCTAssertEqual(stats.agents[0].turnIndex, 3)
    }

    func testDurationIsDifferenceOfFirstAndLastTimestamp() {
        let stats = StatsComputer.compute(turns: buildFixtureTurns())
        // 10:00:00 → 10:01:00 = 60s
        XCTAssertNotNil(stats.duration)
        XCTAssertEqual(stats.duration ?? -1, 60, accuracy: 0.001)
    }

    func testCharCountsForUserAndAssistant() {
        let stats = StatsComputer.compute(turns: buildFixtureTurns())
        // user: "hello"(5) + "list files"(10) + "do file work"(12) + "fan out"(7) = 34
        XCTAssertEqual(stats.charCounts.user, 34)
        // assistant text: "Hi, ready to help."(18) + "done"(4) = 22
        XCTAssertEqual(stats.charCounts.assistant, 22)
        // thinking: "let me think"(12)
        XCTAssertEqual(stats.charCounts.thinking, 12)
    }

    func testTeamOperationsExtracted() {
        let create = ToolCall(
            toolUseId: "tu_team_1",
            name: "TeamCreate",
            input: ["team_name": AnyCodable("reviewers")]
        )
        let delete = ToolCall(
            toolUseId: "tu_team_2",
            name: "TeamDelete",
            input: ["team_name": AnyCodable("reviewers")]
        )
        let turn = Turn(
            index: 0,
            userText: "spin up a team",
            blocks: [
                AssistantBlock(kind: .toolUse, text: "", toolCall: create),
                AssistantBlock(kind: .toolUse, text: "", toolCall: delete),
            ],
            timestamp: "2025-01-01T10:00:00Z"
        )
        let stats = StatsComputer.compute(turns: [turn])
        XCTAssertEqual(stats.teams.count, 2)
        XCTAssertEqual(stats.teams[0].action, "TeamCreate")
        XCTAssertEqual(stats.teams[0].teamName, "reviewers")
        XCTAssertEqual(stats.teams[1].action, "TeamDelete")
    }

    func testAgentFallsBackToSubagentTypeWhenNoDescription() {
        let call = ToolCall(
            toolUseId: "tu_agent_x",
            name: "Agent",
            input: ["subagent_type": AnyCodable("Plan"), "prompt": AnyCodable("plan it")]
        )
        let turn = Turn(
            index: 0,
            userText: "go",
            blocks: [AssistantBlock(kind: .toolUse, text: "", toolCall: call)],
            timestamp: "2025-01-01T10:00:00Z"
        )
        let stats = StatsComputer.compute(turns: [turn])
        XCTAssertEqual(stats.agents.first?.name, "Plan")
    }

    func testEmptyInputReturnsZeroes() {
        let stats = StatsComputer.compute(turns: [])
        XCTAssertEqual(stats.turnCount, 0)
        XCTAssertEqual(stats.blockCounts.text, 0)
        XCTAssertEqual(stats.blockCounts.thinking, 0)
        XCTAssertEqual(stats.blockCounts.toolUse, 0)
        XCTAssertNil(stats.duration)
        XCTAssertNil(stats.longestTurn)
        XCTAssertEqual(stats.avgBlocksPerTurn, 0.0, accuracy: 0.0001)
    }
}
