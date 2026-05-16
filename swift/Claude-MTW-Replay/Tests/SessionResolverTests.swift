import XCTest
@testable import Claude_MTW_Replay

/// Unit tests for `SessionResolver.resolve(sessionId:home:)`.
///
/// Uses the `home` override to point at a per-test temporary directory so
/// the resolver only sees fixtures we control. Mirrors the structure the
/// production resolver walks for Claude Code, Cursor, and Codex CLI.
final class SessionResolverTests: XCTestCase {

    private var tmpHome: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        try super.setUpWithError()
        tmpHome = fm.temporaryDirectory.appendingPathComponent(
            "SessionResolverTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try fm.createDirectory(at: tmpHome, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tmpHome, fm.fileExists(atPath: tmpHome.path) {
            try? fm.removeItem(at: tmpHome)
        }
        tmpHome = nil
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    @discardableResult
    private func touch(_ url: URL, contents: String = "{}\n") throws -> URL {
        try fm.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Claude Code

    func testClaudeExactMatchReturnsPath() throws {
        let sessionId = "11111111-2222-3333-4444-555555555555"
        let projDir = tmpHome.appendingPathComponent(
            ".claude/projects/-Users-test-my-project",
            isDirectory: true
        )
        let target = projDir.appendingPathComponent("\(sessionId).jsonl")
        try touch(target)

        let matches = SessionResolver.resolve(sessionId: sessionId, home: tmpHome)
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.id, sessionId)
        XCTAssertEqual(matches.first?.group, "Claude Code")
        XCTAssertEqual(matches.first?.path, target)
    }

    // MARK: - Cursor

    func testCursorTranscriptJsonlMatch() throws {
        let sessionId = "cursor-session-abc"
        let target = tmpHome.appendingPathComponent(
            ".cursor/projects/-Users-test-my-app/agent-transcripts/\(sessionId)/transcript.jsonl"
        )
        try touch(target)

        let matches = SessionResolver.resolve(sessionId: sessionId, home: tmpHome)
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.group, "Cursor")
        XCTAssertEqual(matches.first?.path, target)
    }

    // MARK: - Codex CLI

    func testCodexPartialUUIDMatch() throws {
        // The resolver matches when the bareId is a substring of the UUID
        // portion of `rollout-YYYY-MM-DD-...<uuid>.jsonl`.
        let partial = "deadbeef"
        let fileName = "rollout-2025-01-15T12-34-56-cafef00d-\(partial)-baadf00d.jsonl"
        let target = tmpHome.appendingPathComponent(
            ".codex/sessions/2025/01/15/\(fileName)"
        )
        try touch(target)

        let matches = SessionResolver.resolve(sessionId: partial, home: tmpHome)
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.group, "Codex CLI")
        XCTAssertEqual(matches.first?.path, target)
        XCTAssertEqual(matches.first?.project, "2025-01-15")
    }

    func testCodexExactFileMatch() throws {
        let sessionId = "exact-codex-id"
        let target = tmpHome.appendingPathComponent(
            ".codex/sessions/2025/02/20/\(sessionId).jsonl"
        )
        try touch(target)

        let matches = SessionResolver.resolve(sessionId: sessionId, home: tmpHome)
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.group, "Codex CLI")
        XCTAssertEqual(matches.first?.path, target)
    }

    // MARK: - Not found

    func testReturnsEmptyForUnknownSessionId() {
        let matches = SessionResolver.resolve(
            sessionId: "does-not-exist",
            home: tmpHome
        )
        XCTAssertTrue(matches.isEmpty)
    }
}
