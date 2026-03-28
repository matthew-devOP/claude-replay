import Foundation

// MARK: - Secret detection and redaction for replay output

private let redactedPlaceholder = "[REDACTED]"

/// A single redaction rule: a human-readable name and its compiled regex.
struct RedactRule {
    let name: String
    let pattern: NSRegularExpression
}

/// All 11 secret patterns ported from secrets.mjs.
let secretPatterns: [RedactRule] = {
    func rule(_ name: String, _ pattern: String, options: NSRegularExpression.Options = []) -> RedactRule {
        // Force-try is acceptable here – these are compile-time-constant patterns.
        // swiftlint:disable:next force_try
        let regex = try! NSRegularExpression(pattern: pattern, options: options)
        return RedactRule(name: name, pattern: regex)
    }

    return [
        // Private keys (multi-line)
        rule("private_key",
             #"-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----[\s\S]*?-----END (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----"#,
             options: .dotMatchesLineSeparators),
        // AWS access key IDs
        rule("aws_key",
             #"AKIA[0-9A-Z]{16}"#),
        // Anthropic API keys
        rule("sk_ant_key",
             #"sk-ant-[a-zA-Z0-9\-]{20,}"#),
        // Generic sk- prefixed secrets
        rule("sk_key",
             #"sk-[a-zA-Z0-9]{20,}"#),
        // Generic key- prefixed secrets
        rule("key_prefix",
             #"key-[a-zA-Z0-9]{20,}"#),
        // Bearer tokens
        rule("bearer",
             #"Bearer [A-Za-z0-9_.~+/=\-]{20,}"#),
        // JWT tokens
        rule("jwt",
             #"eyJ[A-Za-z0-9_\-]{10,}\.eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]+"#),
        // Connection strings
        rule("connection_string",
             #"(?:mongodb|postgres|mysql|redis|amqp|mssql)://[^\s"']+"#),
        // Generic key=value secrets
        rule("key_value",
             #"(?:api[_\-]?key|api[_\-]?secret|secret[_\-]?key|access[_\-]?key|auth[_\-]?token|bearer)\s*[:=]\s*["']?[^\s"',]{8,}["']?"#,
             options: .caseInsensitive),
        // Env var patterns (PASSWORD=..., TOKEN=..., etc.)
        rule("env_var",
             #"(?:PASSWORD|TOKEN|SECRET|CREDENTIAL|PRIVATE_KEY)=[^\s]+"#),
        // Standalone hex tokens (40+ hex chars, word-bounded)
        rule("hex_token",
             #"\b[0-9a-fA-F]{40,}\b"#),
    ]
}()

// MARK: - Public API

/// Replace detected secrets in a string with `[REDACTED]`.
func redactSecrets(_ text: String) -> String {
    var result = text
    let nsRange = NSRange(result.startIndex..., in: result)
    _ = nsRange // just to declare once for the initial range

    for rule in secretPatterns {
        // Recompute range each iteration because replacements change length.
        let currentRange = NSRange(result.startIndex..., in: result)
        result = rule.pattern.stringByReplacingMatches(
            in: result,
            options: [],
            range: currentRange,
            withTemplate: redactedPlaceholder
        )
    }
    return result
}

/// Recursively walk a JSON-compatible object (dictionaries, arrays, strings)
/// and redact any secret values found in strings.
///
/// Supported types: `String`, `[Any]`, `[String: Any]`.  All other types are
/// returned unchanged.
func redactObject(_ obj: Any) -> Any {
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
/// Useful when you want to pass a redactor as a first-class function.
func buildRedactor() -> (String) -> String {
    return { text in redactSecrets(text) }
}
