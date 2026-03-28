import Foundation

// MARK: - String convenience for secret redaction

extension String {

    /// Return a copy of the string with detected secrets replaced by `[REDACTED]`.
    func redacted() -> String {
        redactSecrets(self)
    }
}
