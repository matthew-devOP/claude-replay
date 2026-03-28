import Foundation

// MARK: - FileManager convenience helpers for session discovery

extension FileManager {

    /// The current user's home directory.
    var homeDirectoryURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
    }

    /// Known session root directories keyed by source name.
    /// - Claude Code: `~/.claude/projects`
    /// - Cursor:      `~/.cursor/projects`
    /// - Codex CLI:   `~/.codex/sessions`
    var sessionRootDirectories: [(source: String, url: URL)] {
        let home = homeDirectoryURL
        return [
            ("claude", home.appendingPathComponent(".claude/projects")),
            ("cursor", home.appendingPathComponent(".cursor/projects")),
            ("codex",  home.appendingPathComponent(".codex/sessions")),
        ]
    }

    // MARK: - Directory helpers

    /// Returns sorted subdirectory names inside `directory`, or an empty array
    /// if the path does not exist or is not readable.
    func sortedSubdirectories(at directory: URL) -> [String] {
        guard let entries = try? contentsOfDirectory(atPath: directory.path) else {
            return []
        }
        return entries
            .filter { name in
                var isDir: ObjCBool = false
                let full = directory.appendingPathComponent(name).path
                return fileExists(atPath: full, isDirectory: &isDir) && isDir.boolValue
            }
            .sorted()
    }

    // MARK: - JSONL listing

    /// Lists `.jsonl` filenames inside `directory`, sorted descending (newest first).
    func jsonlFiles(in directory: URL) -> [String] {
        guard let entries = try? contentsOfDirectory(atPath: directory.path) else {
            return []
        }
        return entries
            .filter { $0.hasSuffix(".jsonl") }
            .sorted()
            .reversed()
    }

    // MARK: - Stat helpers

    /// Modification date of `url`, or `nil` on failure.
    func modificationDate(of url: URL) -> Date? {
        try? attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }

    /// File size in bytes, or `0` on failure.
    func fileSize(of url: URL) -> UInt64 {
        (try? attributesOfItem(atPath: url.path)[.size] as? UInt64) ?? 0
    }

    /// Returns `true` when `path` is an existing directory.
    func isDirectory(at path: String) -> Bool {
        var isDir: ObjCBool = false
        return fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    /// Returns `true` when `url` points to an existing regular file.
    func isRegularFile(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fileExists(atPath: url.path, isDirectory: &isDir) && !isDir.boolValue
    }
}
