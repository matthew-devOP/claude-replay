import XCTest
@testable import Claude_MTW_Replay

/// Unit tests for `MarkdownExporter.turnsToMarkdown(_:title:)`.
///
/// Mirrors the conventions in `editor-server.mjs#turnsToMarkdown`: text
/// blocks render as paragraphs, thinking blocks as `<details>` blocks,
/// tool_use blocks as `#### Tool: <name>` headers with fenced bodies.
final class MarkdownExporterTests: XCTestCase {

    // MARK: - Helpers

    private func makeTextOnlyTurn() -> Turn {
        Turn(
            index: 0,
            userText: "hi there",
            blocks: [AssistantBlock(kind: .text, text: "Hello, world!")]
        )
    }

    // MARK: - Tests

    func testTextBlockRendersAsParagraph() {
        let md = MarkdownExporter.turnsToMarkdown([makeTextOnlyTurn()], title: "T")
        XCTAssertTrue(md.contains("# T"))
        XCTAssertTrue(md.contains("## Turn 0"))
        XCTAssertTrue(md.contains("### User"))
        XCTAssertTrue(md.contains("hi there"))
        XCTAssertTrue(md.contains("### Assistant"))
        XCTAssertTrue(md.contains("Hello, world!"))
    }

    func testThinkingBlockRendersAsDetailsSummary() {
        let turn = Turn(
            index: 0,
            userText: "",
            blocks: [AssistantBlock(kind: .thinking, text: "internal monologue")]
        )
        let md = MarkdownExporter.turnsToMarkdown([turn])
        XCTAssertTrue(md.contains("<details>"))
        XCTAssertTrue(md.contains("<summary>Thinking</summary>"))
        XCTAssertTrue(md.contains("internal monologue"))
        XCTAssertTrue(md.contains("</details>"))
    }

    func testBashToolUseRendersFencedCodeBlock() {
        let bash = ToolCall(
            toolUseId: "tu_bash",
            name: "Bash",
            input: ["command": AnyCodable("ls -la")]
        )
        let turn = Turn(
            index: 1,
            userText: "list files",
            blocks: [AssistantBlock(kind: .toolUse, text: "", toolCall: bash)]
        )
        let md = MarkdownExporter.turnsToMarkdown([turn])
        XCTAssertTrue(md.contains("#### Tool: Bash"))
        XCTAssertTrue(md.contains("```bash"))
        XCTAssertTrue(md.contains("ls -la"))
        XCTAssertTrue(md.contains("```"))
    }

    func testEditToolUseRendersDiff() {
        let edit = ToolCall(
            toolUseId: "tu_edit",
            name: "Edit",
            input: [
                "file_path": AnyCodable("/tmp/a.txt"),
                "old_string": AnyCodable("foo"),
                "new_string": AnyCodable("bar"),
            ]
        )
        let turn = Turn(
            index: 2,
            userText: "edit",
            blocks: [AssistantBlock(kind: .toolUse, text: "", toolCall: edit)]
        )
        let md = MarkdownExporter.turnsToMarkdown([turn])
        XCTAssertTrue(md.contains("#### Tool: Edit"))
        XCTAssertTrue(md.contains("**File:** `/tmp/a.txt`"))
        XCTAssertTrue(md.contains("```diff"))
        XCTAssertTrue(md.contains("- foo"))
        XCTAssertTrue(md.contains("+ bar"))
    }

    func testToolResultErrorLabelled() {
        var bash = ToolCall(
            toolUseId: "tu_bash_err",
            name: "Bash",
            input: ["command": AnyCodable("false")],
            result: "exit status 1",
            isError: true
        )
        bash.result = "exit status 1"
        let turn = Turn(
            index: 3,
            userText: "fail",
            blocks: [AssistantBlock(kind: .toolUse, text: "", toolCall: bash)]
        )
        let md = MarkdownExporter.turnsToMarkdown([turn])
        XCTAssertTrue(md.contains("**Error:**"))
        XCTAssertTrue(md.contains("exit status 1"))
    }

    /// Snapshot guard: a minimal text-only turn produces the exact expected
    /// markdown layout. Lets us catch accidental formatting drift.
    func testSnapshotForMinimalTextTurn() {
        let md = MarkdownExporter.turnsToMarkdown([makeTextOnlyTurn()], title: "Demo")
        let expected = """
        # Demo

        ---

        ## Turn 0

        ### User

        hi there

        ### Assistant

        Hello, world!

        """
        XCTAssertEqual(md, expected)
    }
}
