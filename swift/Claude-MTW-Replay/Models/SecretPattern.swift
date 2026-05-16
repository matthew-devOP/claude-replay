import Foundation

/// A named regular-expression rule used to detect a class of secrets in text.
///
/// This is a pure data type. The canonical list of patterns lives in
/// `SecretRedactor.patterns` (see `Services/SecretRedactor.swift`) — the
/// single source of truth that mirrors `src/secrets.mjs` on the web side.
struct SecretPattern: Sendable {
    let name: String
    let pattern: NSRegularExpression

    init(name: String, pattern: String, options: NSRegularExpression.Options = []) {
        self.name = name
        // Force-try is acceptable here: patterns are compile-time constants.
        // swiftlint:disable:next force_try
        self.pattern = try! NSRegularExpression(pattern: pattern, options: options)
    }

    /// Returns the text with all matches of this pattern replaced by `[REDACTED]`.
    func redact(_ text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        return pattern.stringByReplacingMatches(in: text, range: range, withTemplate: "[REDACTED]")
    }
}
