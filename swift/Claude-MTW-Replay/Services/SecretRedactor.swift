import Foundation

// MARK: - Secret detection and redaction for replay output

private let redactedPlaceholder = "[REDACTED]"

// MARK: - Public API

/// Single source of truth for secret detection + redaction in the Swift app.
///
/// The canonical 11-pattern list mirrors `src/secrets.mjs` on the web side
/// (see `test/test-secrets.mjs` for the shared test corpus). `SecretPattern`
/// in `Models/` is a pure data type — all patterns live here.
enum SecretRedactor {

    /// All 11 secret patterns ported from `src/secrets.mjs`. This is the
    /// canonical list — do **not** duplicate this data anywhere else in the
    /// codebase. Add new categories here and add a matching test in
    /// `SecretRedactorTests`.
    static let patterns: [SecretPattern] = [
        // Private keys (multi-line, checked first so the multi-line match
        // wins before inner hex/base64-shaped substrings get redacted).
        SecretPattern(
            name: "private_key",
            pattern: #"-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----[\s\S]*?-----END (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----"#,
            options: .dotMatchesLineSeparators
        ),
        // AWS access key IDs
        SecretPattern(name: "aws_key", pattern: #"AKIA[0-9A-Z]{16}"#),
        // Anthropic API keys (must precede the generic sk- rule)
        SecretPattern(name: "sk_ant_key", pattern: #"sk-ant-[a-zA-Z0-9\-]{20,}"#),
        // Generic sk- prefixed secrets (OpenAI etc.)
        SecretPattern(name: "sk_key", pattern: #"sk-[a-zA-Z0-9]{20,}"#),
        // Generic key- prefixed secrets
        SecretPattern(name: "key_prefix", pattern: #"key-[a-zA-Z0-9]{20,}"#),
        // Bearer tokens
        SecretPattern(name: "bearer", pattern: #"Bearer [A-Za-z0-9_.~+/=\-]{20,}"#),
        // JWT tokens (header.payload.signature)
        SecretPattern(
            name: "jwt",
            pattern: #"eyJ[A-Za-z0-9_\-]{10,}\.eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]+"#
        ),
        // Connection strings (mongodb://, postgres://, mysql://, …)
        SecretPattern(
            name: "connection_string",
            pattern: #"(?:mongodb|postgres|mysql|redis|amqp|mssql)://[^\s"']+"#
        ),
        // Generic key=value or key: "value" secrets
        SecretPattern(
            name: "key_value",
            pattern: #"(?:api[_\-]?key|api[_\-]?secret|secret[_\-]?key|access[_\-]?key|auth[_\-]?token|bearer)\s*[:=]\s*["']?[^\s"',]{8,}["']?"#,
            options: .caseInsensitive
        ),
        // Env-var patterns (PASSWORD=…, TOKEN=…, etc.)
        SecretPattern(
            name: "env_var",
            pattern: #"(?:PASSWORD|TOKEN|SECRET|CREDENTIAL|PRIVATE_KEY)=[^\s]+"#
        ),
        // Standalone long hex tokens (40+ hex chars, word-bounded)
        SecretPattern(name: "hex_token", pattern: #"\b[0-9a-fA-F]{40,}\b"#),
    ]

    /// Replace detected secrets in a string with `[REDACTED]`.
    static func redactSecrets(_ text: String) -> String {
        patterns.reduce(text) { acc, p in p.redact(acc) }
    }

    /// Recursively walk a JSON-compatible object and redact secret strings.
    static func redactObject(_ obj: Any) -> Any {
        if let str = obj as? String {
            return redactSecrets(str)
        }
        if let arr = obj as? [Any] {
            return arr.map { redactObject($0) }
        }
        if let dict = obj as? [String: Any] {
            var out: [String: Any] = [:]
            for (key, value) in dict {
                out[key] = redactObject(value)
            }
            return out
        }
        return obj
    }

    /// Build a closure that captures the shared pattern list and redacts strings.
    static func buildRedactor() -> (String) -> String {
        return { text in redactSecrets(text) }
    }
}
