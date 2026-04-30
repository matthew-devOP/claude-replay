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

    func testDecodesAgentEventReencodesInner() {
        let line = #"{"type":"agent_event","event":{"foo":1,"bar":"baz"}}"#
        guard case .agentEvent(let json) = StreamEvent.decode(line: line) else {
            return XCTFail("expected agentEvent")
        }
        // Inner JSON re-encoded; key order may differ across runtimes.
        XCTAssertTrue(json.contains("\"foo\":1"))
        XCTAssertTrue(json.contains("\"bar\":\"baz\""))
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
