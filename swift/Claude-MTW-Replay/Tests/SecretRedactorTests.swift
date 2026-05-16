import XCTest
@testable import Claude_MTW_Replay

/// Swift port of `test/test-secrets.mjs`. The web file is the source of
/// truth — every `it(...)` in the Node test suite has a one-to-one
/// counterpart here so parity drift is immediately visible.
///
/// Layout mirrors `test-secrets.mjs`:
///   - `redactSecrets` group: 14 cases
///   - `redactObject`   group:  3 cases
///   - Total: 17 cases
final class SecretRedactorTests: XCTestCase {

    private let R = "[REDACTED]"

    // MARK: - redactSecrets

    func testRedactsSkApiKeys() {
        let input = "key is sk-abc123def456ghi789jkl012mno"
        XCTAssertEqual(SecretRedactor.redactSecrets(input), "key is \(R)")
    }

    func testRedactsSkAntAnthropicKeys() {
        let input = "sk-ant-api03-abcdefghijklmnopqrstuvwxyz"
        XCTAssertEqual(SecretRedactor.redactSecrets(input), R)
    }

    func testRedactsKeyPrefixedSecrets() {
        let input = "use key-abcdefghijklmnopqrstuvwxyz here"
        XCTAssertEqual(SecretRedactor.redactSecrets(input), "use \(R) here")
    }

    func testRedactsAwsAccessKeyIds() {
        let input = "aws key: AKIAIOSFODNN7EXAMPLE"
        XCTAssertEqual(SecretRedactor.redactSecrets(input), "aws key: \(R)")
    }

    func testRedactsBearerTokens() {
        let input = "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6Ik"
        XCTAssertEqual(SecretRedactor.redactSecrets(input), "Authorization: \(R)")
    }

    func testRedactsJwtTokens() {
        let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
        XCTAssertEqual(SecretRedactor.redactSecrets("token: \(jwt)"), "token: \(R)")
    }

    func testRedactsConnectionStrings() {
        XCTAssertEqual(
            SecretRedactor.redactSecrets("mongodb://user:pass@host:27017/db"),
            R
        )
        XCTAssertEqual(
            SecretRedactor.redactSecrets("postgres://admin:secret@localhost/mydb"),
            R
        )
    }

    func testRedactsGenericKeyValueSecrets() {
        XCTAssertEqual(
            SecretRedactor.redactSecrets("api_key=supersecretvalue123"),
            R
        )
        XCTAssertTrue(
            SecretRedactor.redactSecrets("auth_token: \"abcdefghijklmnop\"").contains(R),
            "expected [REDACTED] inside the redacted auth_token line"
        )
        XCTAssertEqual(
            SecretRedactor.redactSecrets("secret_key = my_very_secret_val"),
            R
        )
    }

    func testRedactsEnvVarPatterns() {
        XCTAssertEqual(SecretRedactor.redactSecrets("PASSWORD=hunter2"), R)
        XCTAssertEqual(SecretRedactor.redactSecrets("TOKEN=abc123xyz"), R)
    }

    func testRedactsPrivateKeys() {
        let pem = """
        -----BEGIN RSA PRIVATE KEY-----
        MIIEowIBAAKCAQEA0Z3VS5JJcds3xfn/ygWyF...
        -----END RSA PRIVATE KEY-----
        """
        XCTAssertEqual(SecretRedactor.redactSecrets(pem), R)
    }

    func testRedactsLongHexTokens() {
        let hex = "a]" + String(repeating: "b", count: 40) + "[z"
        let result = SecretRedactor.redactSecrets(hex)
        XCTAssertTrue(result.contains(R), "expected long hex run to be redacted, got: \(result)")
    }

    func testLeavesNormalTextUnchanged() {
        let text = "Hello, this is a normal message with no secrets."
        XCTAssertEqual(SecretRedactor.redactSecrets(text), text)
    }

    func testLeavesShortHexStringsUnchanged() {
        let text = "commit abc123 is good"
        XCTAssertEqual(SecretRedactor.redactSecrets(text), text)
    }

    /// Node's `redactSecrets(non-string)` returns the input unchanged. The
    /// Swift API is strongly typed (`String -> String`), so the analogue is
    /// `redactObject(Any)`: non-string values must pass through untouched.
    func testHandlesNonStringInputGracefully() {
        XCTAssertEqual(SecretRedactor.redactObject(42) as? Int, 42)
        XCTAssertTrue(SecretRedactor.redactObject(NSNull()) is NSNull)
        XCTAssertEqual(SecretRedactor.redactObject(true) as? Bool, true)
    }

    // MARK: - redactObject

    func testRedactsStringsInNestedObjects() {
        let obj: [String: Any] = [
            "command": "curl -H 'Authorization: Bearer eyJhbGciOiJIUzIeyJzdWIiOiIxMjM0eyJhbGciOiJI'",
            "nested": [
                "key": "sk-abcdefghijklmnopqrstuvwxyz",
                "safe": "hello",
            ] as [String: Any],
        ]
        let result = SecretRedactor.redactObject(obj) as? [String: Any]
        XCTAssertNotNil(result)
        let command = result?["command"] as? String ?? ""
        XCTAssertTrue(command.contains(R), "expected command to contain [REDACTED], got: \(command)")
        let nested = result?["nested"] as? [String: Any]
        XCTAssertEqual(nested?["key"] as? String, R)
        XCTAssertEqual(nested?["safe"] as? String, "hello")
    }

    func testRedactsStringsInArrays() {
        let arr: [Any] = ["safe", "PASSWORD=hunter2", 42]
        let result = SecretRedactor.redactObject(arr) as? [Any]
        XCTAssertNotNil(result)
        XCTAssertEqual(result?[0] as? String, "safe")
        XCTAssertEqual(result?[1] as? String, R)
        XCTAssertEqual(result?[2] as? Int, 42)
    }

    func testHandlesNullAndPrimitives() {
        XCTAssertTrue(SecretRedactor.redactObject(NSNull()) is NSNull)
        XCTAssertEqual(SecretRedactor.redactObject(42) as? Int, 42)
        XCTAssertEqual(SecretRedactor.redactObject(true) as? Bool, true)
    }

    // MARK: - Single-source invariant

    /// Guard the P2.1 contract: the canonical pattern list lives **only** in
    /// `SecretRedactor.patterns`. If somebody re-adds a hard-coded mirror
    /// list elsewhere we want a test to break.
    func testCanonicalPatternCountMatchesWeb() {
        // `src/secrets.mjs` defines 11 patterns. Adjust here if/when the
        // web list grows — the two must stay in lockstep.
        XCTAssertEqual(SecretRedactor.patterns.count, 11)
        let names = SecretRedactor.patterns.map(\.name)
        let expected = [
            "private_key", "aws_key", "sk_ant_key", "sk_key", "key_prefix",
            "bearer", "jwt", "connection_string", "key_value", "env_var",
            "hex_token",
        ]
        XCTAssertEqual(names, expected)
    }
}
