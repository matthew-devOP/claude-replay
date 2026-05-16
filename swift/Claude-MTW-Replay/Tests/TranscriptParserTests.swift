import XCTest
@testable import Claude_MTW_Replay

/// Port of `test/test-parser.mjs` (Node test runner) to Swift XCTest.
/// Source-of-truth fixtures live in `Tests/Fixtures/*.jsonl` and are bundled
/// into the unit-test bundle as resources via `project.yml`.
final class TranscriptParserTests: XCTestCase {

    // MARK: - Fixture path resolution

    /// Resolve a fixture path. Prefers the test bundle; falls back to the
    /// repository's `test/` directory so the tests also work when invoked
    /// outside the Xcode-built bundle (e.g. swift-test in another harness).
    private func fixturePath(_ name: String) -> String {
        let bundle = Bundle(for: type(of: self))
        if let p = bundle.path(forResource: name, ofType: "jsonl") { return p }
        if let p = bundle.path(forResource: name, ofType: "jsonl", inDirectory: "Fixtures") {
            return p
        }
        let repoFallback = "/Users/anonymous-dd/work/claude-replay/test/\(name).jsonl"
        if FileManager.default.fileExists(atPath: repoFallback) { return repoFallback }
        let bundledFallback = "/Users/anonymous-dd/work/claude-replay/swift/Claude-MTW-Replay/Tests/Fixtures/\(name).jsonl"
        return bundledFallback
    }

    private var FIXTURE: String              { fixturePath("fixture") }
    private var CURSOR_FIXTURE: String       { fixturePath("fixture-cursor") }
    private var CODEX_FIXTURE: String        { fixturePath("fixture-codex") }
    private var PACED_FIXTURE: String        { fixturePath("fixture-paced") }
    private var SYSTEM_TAGS_FIXTURE: String  { fixturePath("fixture-system-tags") }
    private var CODEX_PATCH_FIXTURE: String  { fixturePath("fixture-codex-patch") }
    private var CODEX_EDGES_FIXTURE: String  { fixturePath("fixture-codex-edges") }

    // MARK: - parseTranscript (Claude Code basic fixture, 8 tests)

    func testParsesTurnsFromJsonl() {
        let turns = TranscriptParser.parseTranscript(filePath: FIXTURE)
        XCTAssertEqual(turns.count, 3)
    }

    func testExtractsUserText() {
        let turns = TranscriptParser.parseTranscript(filePath: FIXTURE)
        XCTAssertEqual(turns[0].userText, "Hello, what is 2+2?")
        XCTAssertEqual(turns[2].userText, "Thanks!")
    }

    func testMergesContinuationAssistantBlocksIntoPreviousTurn() {
        let turns = TranscriptParser.parseTranscript(filePath: FIXTURE)
        let toolBlocks = turns[1].blocks.filter { $0.kind == .toolUse }
        XCTAssertEqual(toolBlocks.count, 1)
        let textBlocks = turns[1].blocks.filter { $0.kind == .text }
        XCTAssertEqual(textBlocks.count, 1)
        XCTAssertTrue(textBlocks[0].text.range(of: "file contains") != nil)
    }

    func testExtractsThinkingBlocks() {
        let turns = TranscriptParser.parseTranscript(filePath: FIXTURE)
        let thinking = turns[0].blocks.filter { $0.kind == .thinking }
        XCTAssertEqual(thinking.count, 1)
        XCTAssertTrue(thinking[0].text.range(of: "simple math") != nil)
    }

    func testExtractsTextBlocks() {
        let turns = TranscriptParser.parseTranscript(filePath: FIXTURE)
        let text = turns[0].blocks.filter { $0.kind == .text }
        XCTAssertEqual(text.count, 1)
        XCTAssertEqual(text[0].text, "2 + 2 = 4")
    }

    func testExtractsToolCallsWithResults() {
        let turns = TranscriptParser.parseTranscript(filePath: FIXTURE)
        let toolBlocks = turns[1].blocks.filter { $0.kind == .toolUse }
        XCTAssertEqual(toolBlocks.count, 1)
        XCTAssertEqual(toolBlocks[0].toolCall?.name, "Read")
        XCTAssertEqual(toolBlocks[0].toolCall?.result, "file contents here")
    }

    func testAssignsSequentialTurnIndices() {
        let turns = TranscriptParser.parseTranscript(filePath: FIXTURE)
        XCTAssertEqual(turns.map(\.index), [1, 2, 3])
    }

    func testPreservesTimestamps() {
        let turns = TranscriptParser.parseTranscript(filePath: FIXTURE)
        XCTAssertEqual(turns[0].timestamp, "2025-06-01T10:00:00Z")
    }

    // MARK: - filterTurns (5 tests)

    func testFiltersByTurnRange() {
        let turns = TranscriptParser.parseTranscript(filePath: FIXTURE)
        var opts = FilterOptions()
        opts.turnRange = (2, 3)
        let filtered = TranscriptParser.filterTurns(turns, options: opts)
        XCTAssertEqual(filtered.count, 2)
        XCTAssertEqual(filtered[0].index, 2)
    }

    func testFiltersByTimeRange() {
        let turns = TranscriptParser.parseTranscript(filePath: FIXTURE)
        var opts = FilterOptions()
        opts.timeFrom = "2025-06-01T10:01:00Z"
        opts.timeTo   = "2025-06-01T10:02:05Z"
        let filtered = TranscriptParser.filterTurns(turns, options: opts)
        XCTAssertEqual(filtered.count, 2)
        XCTAssertEqual(filtered[0].index, 2)
    }

    func testExcludesSpecificTurns() {
        let turns = TranscriptParser.parseTranscript(filePath: FIXTURE)
        var opts = FilterOptions()
        opts.excludeTurns = [1, 3]
        let filtered = TranscriptParser.filterTurns(turns, options: opts)
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].index, 2)
    }

    func testCombinesTurnRangeWithExclude() {
        let turns = TranscriptParser.parseTranscript(filePath: FIXTURE)
        var opts = FilterOptions()
        opts.turnRange = (1, 3)
        opts.excludeTurns = [2]
        let filtered = TranscriptParser.filterTurns(turns, options: opts)
        XCTAssertEqual(filtered.count, 2)
        XCTAssertEqual(filtered[0].index, 1)
        XCTAssertEqual(filtered[1].index, 3)
    }

    func testReturnsAllTurnsWithNoFilters() {
        let turns = TranscriptParser.parseTranscript(filePath: FIXTURE)
        let filtered = TranscriptParser.filterTurns(turns)
        XCTAssertEqual(filtered.count, 3)
    }

    // MARK: - Cursor format (6 tests)

    func testCursorParsesEntriesIntoTurns() {
        let turns = TranscriptParser.parseTranscript(filePath: CURSOR_FIXTURE)
        XCTAssertEqual(turns.count, 2)
    }

    func testCursorStripsUserQueryTags() {
        let turns = TranscriptParser.parseTranscript(filePath: CURSOR_FIXTURE)
        XCTAssertEqual(turns[0].userText, "scan for ble devices")
        XCTAssertEqual(turns[1].userText, "connect to the first one")
    }

    func testCursorMergesConsecutiveAssistantMessagesIntoOneTurn() {
        let turns = TranscriptParser.parseTranscript(filePath: CURSOR_FIXTURE)
        XCTAssertEqual(turns[0].blocks.count, 2)
        XCTAssertTrue(turns[0].blocks[0].text.range(of: "Planning scan") != nil)
        XCTAssertTrue(turns[0].blocks[1].text.range(of: "Found 3 devices") != nil)
    }

    func testCursorReclassifiesAllButLastAssistantBlockAsThinking() {
        let turns = TranscriptParser.parseTranscript(filePath: CURSOR_FIXTURE)
        // Turn 1: 2 blocks — first thinking, last text
        XCTAssertEqual(turns[0].blocks[0].kind, .thinking)
        XCTAssertEqual(turns[0].blocks[1].kind, .text)
        // Turn 2: 1 block — stays as text
        XCTAssertEqual(turns[1].blocks[0].kind, .text)
    }

    func testCursorHasNoTimestampsBeforeApplyPacedTiming() {
        let turns = TranscriptParser.parseTranscript(filePath: CURSOR_FIXTURE)
        // The web parser yields "" for missing timestamps; the Swift port
        // either returns nil or "" depending on JSON null vs. missing field.
        let ts = turns[0].timestamp ?? ""
        XCTAssertEqual(ts, "")
    }

    func testDetectFormat() {
        XCTAssertEqual(TranscriptParser.detectFormat(filePath: CURSOR_FIXTURE), .cursor)
        XCTAssertEqual(TranscriptParser.detectFormat(filePath: FIXTURE), .claudeCode)
    }

    // MARK: - Codex format (11 tests)

    func testDetectCodexFormat() {
        XCTAssertEqual(TranscriptParser.detectFormat(filePath: CODEX_FIXTURE), .codex)
    }

    func testCodexParsesTurnsFromTaskBoundaries() {
        let turns = TranscriptParser.parseTranscript(filePath: CODEX_FIXTURE)
        XCTAssertEqual(turns.count, 3)
    }

    func testCodexExtractsUserTextAfterMarker() {
        let turns = TranscriptParser.parseTranscript(filePath: CODEX_FIXTURE)
        XCTAssertEqual(turns[0].userText, "list files here")
        XCTAssertEqual(turns[1].userText, "create hello.txt")
        XCTAssertEqual(turns[2].userText, "fix the typo")
    }

    func testCodexMapsCommentaryToThinkingAndFinalToText() {
        let turns = TranscriptParser.parseTranscript(filePath: CODEX_FIXTURE)
        let thinking = turns[0].blocks.filter { $0.kind == .thinking }
        let text     = turns[0].blocks.filter { $0.kind == .text }
        XCTAssertEqual(thinking.count, 1)
        XCTAssertTrue(thinking[0].text.range(of: "Checking the directory") != nil)
        XCTAssertEqual(text.count, 1)
        XCTAssertEqual(text[0].text, "Found 2 files.")
    }

    func testCodexSkipsEncryptedReasoningBlocks() {
        let turns = TranscriptParser.parseTranscript(filePath: CODEX_FIXTURE)
        let reasoning = turns[0].blocks.filter { $0.text.contains("gAAAA") }
        XCTAssertEqual(reasoning.count, 0)
    }

    func testCodexMapsExecCommandToBashWithNormalizedInput() {
        let turns = TranscriptParser.parseTranscript(filePath: CODEX_FIXTURE)
        let bash = turns[0].blocks.first { $0.kind == .toolUse }
        XCTAssertEqual(bash?.toolCall?.name, "Bash")
        let cmd = bash?.toolCall?.input["command"]?.stringValue
        XCTAssertEqual(cmd, "cd /tmp/test && ls")
    }

    func testCodexStripsMetadataFromToolOutput() {
        let turns = TranscriptParser.parseTranscript(filePath: CODEX_FIXTURE)
        let bash = turns[0].blocks.first { $0.kind == .toolUse }
        XCTAssertEqual(bash?.toolCall?.result, "file1.txt\nfile2.txt")
        XCTAssertFalse(bash?.toolCall?.result?.contains("Chunk ID") ?? true)
    }

    func testCodexMapsApplyPatchAddFileToWrite() {
        let turns = TranscriptParser.parseTranscript(filePath: CODEX_FIXTURE)
        let write = turns[1].blocks.first { $0.kind == .toolUse }
        XCTAssertEqual(write?.toolCall?.name, "Write")
        XCTAssertEqual(write?.toolCall?.input["file_path"]?.stringValue, "/tmp/hello.txt")
        XCTAssertEqual(write?.toolCall?.input["content"]?.stringValue, "hello world")
    }

    func testCodexMapsApplyPatchUpdateFileToEdit() {
        let turns = TranscriptParser.parseTranscript(filePath: CODEX_FIXTURE)
        let edit = turns[2].blocks.first { $0.kind == .toolUse }
        XCTAssertEqual(edit?.toolCall?.name, "Edit")
        XCTAssertEqual(edit?.toolCall?.input["file_path"]?.stringValue, "/tmp/hello.txt")
        XCTAssertEqual(edit?.toolCall?.input["old_string"]?.stringValue, "hello world")
        XCTAssertEqual(edit?.toolCall?.input["new_string"]?.stringValue, "hello, world!")
    }

    func testCodexAttachesToolResultsWithTimestamps() {
        let turns = TranscriptParser.parseTranscript(filePath: CODEX_FIXTURE)
        let edit = turns[2].blocks.first { $0.kind == .toolUse }
        XCTAssertEqual(edit?.toolCall?.result, "Success.")
        XCTAssertNotNil(edit?.toolCall?.resultTimestamp)
        XCTAssertFalse((edit?.toolCall?.resultTimestamp ?? "").isEmpty)
    }

    func testCodexPreservesTimestampsOnTurns() {
        let turns = TranscriptParser.parseTranscript(filePath: CODEX_FIXTURE)
        let ts = turns[0].timestamp ?? ""
        XCTAssertTrue(ts.hasPrefix("2026-03-13"), "expected timestamp to start with 2026-03-13, got \(ts)")
    }

    // MARK: - applyPacedTiming (3 tests)

    func testApplyPacedTimingGeneratesOrderedSyntheticTimestamps() {
        var turns = TranscriptParser.parseTranscript(filePath: PACED_FIXTURE)
        TranscriptParser.applyPacedTiming(&turns)
        XCTAssertNotNil(turns[0].timestamp)
        XCTAssertFalse((turns[0].timestamp ?? "").isEmpty)
        XCTAssertNotNil(turns[0].blocks[0].timestamp)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard
            let t0 = formatter.date(from: turns[0].timestamp ?? ""),
            let t1 = formatter.date(from: turns[1].timestamp ?? "")
        else {
            XCTFail("could not parse paced timestamps")
            return
        }
        XCTAssertGreaterThan(t1, t0)
    }

    func testApplyPacedTimingScalesDurationWithContentLength() {
        var turns = TranscriptParser.parseTranscript(filePath: PACED_FIXTURE)
        TranscriptParser.applyPacedTiming(&turns)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard
            let turn0Ts = formatter.date(from: turns[0].timestamp ?? ""),
            let block0Ts = formatter.date(from: turns[0].blocks[0].timestamp ?? ""),
            let turn1Ts = formatter.date(from: turns[1].timestamp ?? ""),
            let block1Ts = formatter.date(from: turns[1].blocks[0].timestamp ?? "")
        else {
            XCTFail("could not parse paced timestamps")
            return
        }
        let gap0 = block0Ts.timeIntervalSince(turn0Ts)
        let gap1 = block1Ts.timeIntervalSince(turn1Ts)
        XCTAssertEqual(gap0, gap1, accuracy: 0.001)
    }

    func testApplyPacedTimingWorksOnClaudeCodeTranscripts() {
        var turns = TranscriptParser.parseTranscript(filePath: FIXTURE)
        let origTs = turns[0].timestamp
        TranscriptParser.applyPacedTiming(&turns)
        XCTAssertNotEqual(turns[0].timestamp, origTs)
    }

    // MARK: - cleanSystemTags (6 tests)

    func testCleanSystemTagsStripsMultipleSystemReminders() {
        let turns = TranscriptParser.parseTranscript(filePath: SYSTEM_TAGS_FIXTURE)
        XCTAssertEqual(turns[0].userText, "Before reminder\nAfter reminder")
    }

    func testCleanSystemTagsStripsIdeOpenedFile() {
        let turns = TranscriptParser.parseTranscript(filePath: SYSTEM_TAGS_FIXTURE)
        XCTAssertEqual(turns[1].userText, "Check this\nPlease review")
    }

    func testCleanSystemTagsExtractsCommandNameAndKeepsCommandArgs() {
        let turns = TranscriptParser.parseTranscript(filePath: SYSTEM_TAGS_FIXTURE)
        XCTAssertTrue(turns[2].userText.range(of: "review") != nil)
        XCTAssertTrue(turns[2].userText.range(of: "src/main.ts") != nil)
    }

    func testCleanSystemTagsRemovesEmptyCommandArgs() {
        let turns = TranscriptParser.parseTranscript(filePath: SYSTEM_TAGS_FIXTURE)
        XCTAssertFalse(turns[4].userText.contains("command-args"))
    }

    func testCleanSystemTagsStripsLocalCommandCaveatAndStdout() {
        let turns = TranscriptParser.parseTranscript(filePath: SYSTEM_TAGS_FIXTURE)
        XCTAssertEqual(turns[3].userText, "Run this")
    }

    func testCleanSystemTagsHandlesMixedTagsInOneMessage() {
        let turns = TranscriptParser.parseTranscript(filePath: SYSTEM_TAGS_FIXTURE)
        let text = turns[4].userText
        XCTAssertFalse(text.contains("<system-reminder>"))
        XCTAssertFalse(text.contains("<ide_opened_file>"))
        XCTAssertFalse(text.contains("<local-command-caveat>"))
        XCTAssertFalse(text.contains("<local-command-stdout>"))
        XCTAssertTrue(text.range(of: "deploy") != nil)
        XCTAssertTrue(text.range(of: "Actual user message") != nil)
    }

    // MARK: - parseCodexPatch (3 tests)

    func testCodexPatchHandlesPatchWithContextLines() {
        let turns = TranscriptParser.parseTranscript(filePath: CODEX_PATCH_FIXTURE)
        let edit = turns[0].blocks.first { $0.kind == .toolUse }
        XCTAssertEqual(edit?.toolCall?.name, "Edit")
        XCTAssertEqual(edit?.toolCall?.input["file_path"]?.stringValue, "/src/app.js")

        let oldString = edit?.toolCall?.input["old_string"]?.stringValue ?? ""
        let newString = edit?.toolCall?.input["new_string"]?.stringValue ?? ""
        XCTAssertTrue(oldString.range(of: "const x = 1;") != nil)
        XCTAssertTrue(oldString.range(of: "const y = 2;") != nil)
        XCTAssertTrue(oldString.range(of: "const z = 4;") != nil)
        XCTAssertTrue(newString.range(of: "const x = 1;") != nil)
        XCTAssertTrue(newString.range(of: "const y = 3;") != nil)
        XCTAssertTrue(newString.range(of: "const z = 4;") != nil)
    }

    func testCodexPatchHandlesEmptyPatch() {
        let turns = TranscriptParser.parseTranscript(filePath: CODEX_PATCH_FIXTURE)
        let tool = turns[1].blocks.first { $0.kind == .toolUse }
        XCTAssertEqual(tool?.toolCall?.input["file_path"]?.stringValue, "")
        XCTAssertEqual(tool?.toolCall?.input["old_string"]?.stringValue, "")
        XCTAssertEqual(tool?.toolCall?.input["new_string"]?.stringValue, "")
    }

    func testCodexPatchHandlesMultipleFilesInOneTurn() {
        let turns = TranscriptParser.parseTranscript(filePath: CODEX_PATCH_FIXTURE)
        let toolBlocks = turns[2].blocks.filter { $0.kind == .toolUse }
        XCTAssertEqual(toolBlocks.count, 2)
        XCTAssertEqual(toolBlocks[0].toolCall?.name, "Write")
        XCTAssertEqual(toolBlocks[0].toolCall?.input["file_path"]?.stringValue, "/src/new.js")
        XCTAssertEqual(toolBlocks[1].toolCall?.name, "Edit")
        XCTAssertEqual(toolBlocks[1].toolCall?.input["file_path"]?.stringValue, "/src/old.js")
    }

    // MARK: - Codex edge cases (4 tests)

    func testCodexHandlesSessionEndingWithoutTaskComplete() {
        let turns = TranscriptParser.parseTranscript(filePath: CODEX_EDGES_FIXTURE)
        let truncated = turns.first { $0.userText == "truncated session" }
        XCTAssertNotNil(truncated, "truncated turn should be captured")
        XCTAssertGreaterThan(truncated?.blocks.count ?? 0, 0)
    }

    func testCodexHandlesToolCallWithNoResultPending() {
        let turns = TranscriptParser.parseTranscript(filePath: CODEX_EDGES_FIXTURE)
        let pendingTurn = turns.first { $0.userText == "pending tool call" }
        XCTAssertNotNil(pendingTurn)
        let toolBlock = pendingTurn?.blocks.first { $0.kind == .toolUse }
        XCTAssertNotNil(toolBlock)
        XCTAssertEqual(toolBlock?.toolCall?.name, "Bash")
        XCTAssertNil(toolBlock?.toolCall?.result)
    }

    func testCodexUsesFullTextWhenMarkerAbsent() {
        let turns = TranscriptParser.parseTranscript(filePath: CODEX_EDGES_FIXTURE)
        let noMarker = turns.first { $0.userText == "Just do something without the marker" }
        XCTAssertNotNil(noMarker)
    }

    func testCodexCapturesMultipleCommentaryBlocksAsThinking() {
        let turns = TranscriptParser.parseTranscript(filePath: CODEX_EDGES_FIXTURE)
        let multiTurn = turns.first { $0.userText == "multiple commentary blocks" }
        XCTAssertNotNil(multiTurn)
        let thinking = multiTurn?.blocks.filter { $0.kind == .thinking } ?? []
        XCTAssertEqual(thinking.count, 3)
        XCTAssertEqual(thinking[0].text, "First thought.")
        XCTAssertEqual(thinking[1].text, "Second thought.")
        XCTAssertEqual(thinking[2].text, "Third thought.")
        let text = multiTurn?.blocks.filter { $0.kind == .text } ?? []
        XCTAssertEqual(text.count, 1)
        XCTAssertEqual(text[0].text, "Final answer here.")
    }
}
