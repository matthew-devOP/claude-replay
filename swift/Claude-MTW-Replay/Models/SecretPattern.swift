import Foundation

/// A named regular expression pattern for detecting secrets in text.
struct SecretPattern: Sendable {
    let name: String
    let pattern: NSRegularExpression

    init(name: String, pattern: String, options: NSRegularExpression.Options = []) {
        self.name = name
        // Force-try is acceptable here: patterns are compile-time constants.
        // swiftlint:disable:next force_try
        self.pattern = try! NSRegularExpression(pattern: pattern, options: options)
    }

    /// Returns the text with all matches replaced by `[REDACTED]`.
    func redact(_ text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        return pattern.stringByReplacingMatches(in: text, range: range, withTemplate: "[REDACTED]")
    }

    // MARK: - Built-in patterns (mirrors secrets.mjs)

    static let builtIn: [SecretPattern] = [
        SecretPattern(
            name: "private_key",
            pattern: "-----BEGIN[A-Z ]*PRIVATE KEY-----[\\s\\S]*?-----END[A-Z ]*PRIVATE KEY-----",
            options: [.dotMatchesLineSeparators]
        ),
        SecretPattern(name: "aws_key", pattern: "AKIA[0-9A-Z]{16}"),
        SecretPattern(name: "sk_ant_key", pattern: "sk-ant-[A-Za-z0-9_-]{20,}"),
        SecretPattern(name: "sk_key", pattern: "sk-[A-Za-z0-9_-]{20,}"),
        SecretPattern(name: "key_prefix", pattern: "key-[A-Za-z0-9_-]{20,}"),
        SecretPattern(name: "bearer", pattern: "Bearer\\s+[A-Za-z0-9._~+/=-]{20,}"),
        SecretPattern(name: "jwt", pattern: "eyJ[A-Za-z0-9_-]+\\.eyJ[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+"),
        SecretPattern(
            name: "connection_string",
            pattern: "(mongodb|postgres|postgresql|mysql|redis|amqp|mssql)://[^\\s\"'`]+"
        ),
        SecretPattern(
            name: "key_value",
            pattern: "(api_key|secret_key|auth_token|access_token|api_secret|client_secret)\\s*[=:]\\s*[\"']?[A-Za-z0-9._~+/=-]{8,}[\"']?"
        ),
        SecretPattern(
            name: "env_var",
            pattern: "(PASSWORD|TOKEN|SECRET|PRIVATE_KEY|API_KEY)\\s*=\\s*[\"']?[^\\s\"']{8,}[\"']?"
        ),
        SecretPattern(name: "hex_token", pattern: "\\b[0-9a-fA-F]{40,}\\b"),
    ]

    /// Apply all built-in patterns to redact secrets from text.
    static func redactAll(_ text: String) -> String {
        builtIn.reduce(text) { result, pattern in
            pattern.redact(result)
        }
    }
}
