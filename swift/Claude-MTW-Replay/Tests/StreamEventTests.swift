import XCTest
@testable import Claude_MTW_Replay

final class StreamEventTests: XCTestCase {

    func testDecodesReady() {
        let e = StreamEvent.decode(line: #"{"type":"ready","mode":"skeleton"}"#)
        XCTAssertEqual(e, .ready(mode: "skeleton"))
    }

    func testDecodesEcho() {
        let e = StreamEvent.decode(line: #"{"type":"echo","input":"hi"}"#)
        XCTAssertEqual(e, .echo(input: "hi"))
    }

    func testDecodesError() {
        let e = StreamEvent.decode(line: #"{"type":"error","message":"oops"}"#)
        XCTAssertEqual(e, .error(message: "oops"))
    }

    func testDecodesExit() {
        let e = StreamEvent.decode(line: #"{"type":"exit","code":0}"#)
        XCTAssertEqual(e, .exit(code: 0))
    }

    func testDecodesSystemInit() {
        let line = #"{"type":"agent_event","event":{"type":"system","subtype":"init","session_id":"abc","model":"claude-sonnet-4-6","cwd":"/tmp"}}"#
        guard case .agentMessage(.systemInit(let sid, let model, let cwd)) = StreamEvent.decode(line: line) else {
            return XCTFail("expected systemInit")
        }
        XCTAssertEqual(sid, "abc")
        XCTAssertEqual(model, "claude-sonnet-4-6")
        XCTAssertEqual(cwd, "/tmp")
    }

    func testDecodesUserMessage() {
        let line = #"{"type":"agent_event","event":{"type":"user","session_id":"s1","message":{"role":"user","content":"hello world"}}}"#
        guard case .agentMessage(.userMessage(let text, let results, let sid)) = StreamEvent.decode(line: line) else {
            return XCTFail("expected userMessage")
        }
        XCTAssertEqual(text, "hello world")
        XCTAssertTrue(results.isEmpty)
        XCTAssertEqual(sid, "s1")
    }

    func testDecodesUserToolResult() {
        let line = #"{"type":"agent_event","event":{"type":"user","session_id":"s2","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"tu1","content":"42","is_error":false}]}}}"#
        guard case .agentMessage(.userMessage(_, let results, _)) = StreamEvent.decode(line: line) else {
            return XCTFail("expected userMessage")
        }
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].toolUseId, "tu1")
        XCTAssertEqual(results[0].content, "42")
        XCTAssertFalse(results[0].isError)
    }

    func testDecodesAssistantBlocks() {
        let line = #"{"type":"agent_event","event":{"type":"assistant","session_id":"s3","message":{"content":[{"type":"thinking","thinking":"hmm"},{"type":"text","text":"hi"},{"type":"tool_use","id":"tu","name":"Bash","input":{"cmd":"ls"}}]}}}"#
        guard case .agentMessage(.assistantMessage(let blocks, _)) = StreamEvent.decode(line: line) else {
            return XCTFail("expected assistantMessage")
        }
        XCTAssertEqual(blocks.count, 3)
        guard case .thinking(let t1) = blocks[0] else { return XCTFail() }
        XCTAssertEqual(t1, "hmm")
        guard case .text(let t2) = blocks[1] else { return XCTFail() }
        XCTAssertEqual(t2, "hi")
        guard case .toolUse(let id, let name, let inputJson) = blocks[2] else { return XCTFail() }
        XCTAssertEqual(id, "tu")
        XCTAssertEqual(name, "Bash")
        XCTAssertTrue(inputJson.contains("\"cmd\":\"ls\""))
    }

    func testDecodesResult() {
        let line = #"{"type":"agent_event","event":{"type":"result","subtype":"success","is_error":false,"duration_ms":1234,"total_cost_usd":0.05,"num_turns":3}}"#
        guard case .agentMessage(.result(let success, let dur, let cost, let turns, let usage)) = StreamEvent.decode(line: line) else {
            return XCTFail("expected result")
        }
        XCTAssertTrue(success)
        XCTAssertEqual(dur, 1234)
        XCTAssertEqual(cost, 0.05, accuracy: 0.001)
        XCTAssertEqual(turns, 3)
        XCTAssertNil(usage)
    }

    func testDecodesResultWithUsage() {
        let line = #"{"type":"agent_event","event":{"type":"result","subtype":"success","is_error":false,"duration_ms":1234,"total_cost_usd":0.05,"num_turns":3,"usage":{"input_tokens":100,"output_tokens":42,"cache_creation_input_tokens":7,"cache_read_input_tokens":11}}}"#
        guard case .agentMessage(.result(_, _, _, _, let usage)) = StreamEvent.decode(line: line),
              let u = usage else {
            return XCTFail("expected result with usage")
        }
        XCTAssertEqual(u.inputTokens, 100)
        XCTAssertEqual(u.outputTokens, 42)
        XCTAssertEqual(u.cacheCreationInputTokens, 7)
        XCTAssertEqual(u.cacheReadInputTokens, 11)
    }

    func testUnknownTypeFallsThrough() {
        let e = StreamEvent.decode(line: #"{"type":"weird","x":42}"#)
        if case .unknown(let raw) = e {
            XCTAssertTrue(raw.contains("weird"))
        } else {
            XCTFail("expected unknown")
        }
    }

    func testWhitespaceLinesReturnNil() {
        XCTAssertNil(StreamEvent.decode(line: ""))
        XCTAssertNil(StreamEvent.decode(line: "   "))
    }

    func testInvalidJsonFallsThroughAsUnknown() {
        let e = StreamEvent.decode(line: "{not json}")
        if case .unknown = e { /* ok */ } else { XCTFail("expected unknown") }
    }
}
