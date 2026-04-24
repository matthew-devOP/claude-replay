import Foundation

// MARK: - String convenience for secret redaction

extension String {

    /// Return a copy of the string with detected secrets replaced by `[REDACTED]`.
    func redacted() -> String {
        SecretRedactor.redactSecrets(self)
    }

    /// Count non-overlapping case-insensitive occurrences of `substring`.
    func countOccurrences(of substring: String) -> Int {
        guard !substring.isEmpty else { return 0 }
        var count = 0
        var searchRange = startIndex..<endIndex
        while let range = self.range(of: substring, options: .caseInsensitive, range: searchRange) {
            count += 1
            searchRange = range.upperBound..<endIndex
        }
        return count
    }
}
