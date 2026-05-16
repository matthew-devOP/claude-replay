import XCTest
@testable import Claude_MTW_Replay

/// End-to-end smoke against the Node sidecar in skeleton mode.
/// Runs `node sidecar.js --skeleton`, sends two messages, asserts two
/// matching echo events come back, then sends `stop`. Validates that the
/// stdin/stdout plumbing in `ClaudeAgent` works before the real SDK is
/// wired up in step 5.
final class ClaudeAgentSkeletonTests: XCTestCase {

    /// Skipped automatically if `node` isn't on the host (CI without Node).
    func testEchoRoundTrip() async throws {
        guard let _ = try? SidecarLocator.nodeBinary() else {
            throw XCTSkip("node not installed; skeleton round-trip skipped")
        }
        guard let _ = try? SidecarLocator.bundledSidecarScript() else {
            throw XCTSkip("sidecar.js not bundled; build the app target first")
        }

        let agent = ClaudeAgent()
        let opts = ClaudeAgent.StartOptions(
            sessionPath: "/tmp/dummy.jsonl",
            workingDirectory: URL(fileURLWithPath: NSHomeDirectory()),
            permissionMode: "default",
            allowedTools: nil,
            disallowedTools: nil,
            includePartialMessages: false,
            skeleton: true
        )

        let stream = try await agent.start(options: opts)
        var received: [StreamEvent] = []

        let consumer = Task<Void, Error> {
            for try await event in stream {
                received.append(event)
                if case .exit = event { return }
            }
        }

        // Give the spawn time to settle before the first send.
        try? await Task.sleep(nanoseconds: 50_000_000)
        try await agent.send("first")
        try await agent.send("second")
        await agent.stop()
        _ = try? await consumer.value

        let echoes = received.compactMap { evt -> String? in
            if case .echo(let input) = evt { return input } else { return nil }
        }
        XCTAssertTrue(echoes.contains("first"),  "expected echo of 'first', got \(received)")
        XCTAssertTrue(echoes.contains("second"), "expected echo of 'second', got \(received)")
    }
}
