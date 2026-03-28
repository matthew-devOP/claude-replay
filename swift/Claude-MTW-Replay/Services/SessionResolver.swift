import Foundation

// MARK: - Session resolution — find JSONL files by session ID

/// A single match returned by `SessionResolver.resolve`.
struct ResolvedSession: Identifiable, Hashable {
    let id: String           // session ID (filename stem)
    let path: URL            // full path to the .jsonl file
    let project: String      // human-readable project name
    let group: String        // "Claude Code", "Cursor", or "Codex CLI"
}

/// Scans `~/.claude`, `~/.cursor`, and `~/.codex` to locate JSONL session
/// files matching a given session ID.  Direct port of `resolve-session.mjs`.
enum SessionResolver {

    /// Resolve a session ID to every matching JSONL file across all known
    /// tool directories.
    ///
    /// - Parameters:
    ///   - sessionId: The session identifier (with or without `.jsonl`).
    ///   - home: Override for the home directory (useful in tests).
    /// - Returns: An array of `ResolvedSession` matches.
    static func resolve(sessionId: String, home: URL? = nil) -> [ResolvedSession] {
        let fm = FileManager.default
        let homeDir = home ?? fm.homeDirectoryURL
        let target = sessionId.hasSuffix(".jsonl") ? sessionId : sessionId + ".jsonl"
        let bareId = sessionId.hasSuffix(".jsonl")
            ? String(sessionId.dropLast(6))
            : sessionId

        var matches: [ResolvedSession] = []

        // ── Claude Code ─────────────────────────────────────────────────
        // ~/.claude/projects/<project>/<id>.jsonl
        let claudeBase = homeDir.appendingPathComponent(".claude/projects")
        for proj in fm.sortedSubdirectories(at: claudeBase) {
            let filePath = claudeBase
                .appendingPathComponent(proj)
                .appendingPathComponent(target)
            guard fm.isRegularFile(at: filePath) else { continue }
            matches.append(ResolvedSession(
                id: bareId,
                path: filePath,
                project: Self.displayName(from: proj),
                group: "Claude Code"
            ))
        }

        // ── Cursor ──────────────────────────────────────────────────────
        // ~/.cursor/projects/<project>/agent-transcripts/<id>/transcript.jsonl
        // or <id>/<id>.jsonl
        let cursorBase = homeDir.appendingPathComponent(".cursor/projects")
        for proj in fm.sortedSubdirectories(at: cursorBase) {
            let transcriptsDir = cursorBase
                .appendingPathComponent(proj)
                .appendingPathComponent("agent-transcripts")
            let idDir = transcriptsDir.appendingPathComponent(bareId)

            // Try transcript.jsonl first, then <id>.jsonl
            let candidate1 = idDir.appendingPathComponent("transcript.jsonl")
            let candidate2 = idDir.appendingPathComponent(bareId + ".jsonl")

            let filePath: URL
            if fm.isRegularFile(at: candidate1) {
                filePath = candidate1
            } else if fm.isRegularFile(at: candidate2) {
                filePath = candidate2
            } else {
                continue
            }

            matches.append(ResolvedSession(
                id: bareId,
                path: filePath,
                project: Self.displayName(from: proj),
                group: "Cursor"
            ))
        }

        // ── Codex CLI ───────────────────────────────────────────────────
        // ~/.codex/sessions/<YYYY>/<MM>/<DD>/rollout-<timestamp>-<uuid>.jsonl
        let codexBase = homeDir.appendingPathComponent(".codex/sessions")
        let codexUUIDPattern = #"^rollout-\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}-(.+)$"#

        for year in fm.sortedSubdirectories(at: codexBase) {
            let yearURL = codexBase.appendingPathComponent(year)
            for month in fm.sortedSubdirectories(at: yearURL) {
                let monthURL = yearURL.appendingPathComponent(month)
                for day in fm.sortedSubdirectories(at: monthURL) {
                    let dayURL = monthURL.appendingPathComponent(day)
                    guard let files = try? fm.contentsOfDirectory(atPath: dayURL.path) else {
                        continue
                    }
                    for f in files where f.hasSuffix(".jsonl") {
                        let fullPath = dayURL.appendingPathComponent(f)

                        // Exact filename match
                        if f == target {
                            matches.append(ResolvedSession(
                                id: bareId,
                                path: fullPath,
                                project: "\(year)-\(month)-\(day)",
                                group: "Codex CLI"
                            ))
                            continue
                        }

                        // UUID substring match in the UUID portion only
                        let stem = String(f.dropLast(6)) // strip .jsonl
                        if let regex = try? NSRegularExpression(pattern: codexUUIDPattern),
                           let match = regex.firstMatch(
                               in: stem,
                               range: NSRange(stem.startIndex..., in: stem)
                           ),
                           let uuidRange = Range(match.range(at: 1), in: stem) {
                            let uuid = String(stem[uuidRange])
                            if uuid.contains(bareId) {
                                matches.append(ResolvedSession(
                                    id: bareId,
                                    path: fullPath,
                                    project: "\(year)-\(month)-\(day)",
                                    group: "Codex CLI"
                                ))
                            }
                        }
                    }
                }
            }
        }

        return matches
    }

    // MARK: - Helpers

    /// Derive a short display name from a Claude/Cursor project directory
    /// name (e.g. `-Users-joe-my-project` -> `my-project`).
    static func displayName(from dirName: String) -> String {
        let stripped = dirName.drop(while: { $0 == "-" })
        let parts = stripped.split(separator: "-").map(String.init)
        if parts.count > 1 {
            return parts.suffix(2).joined(separator: "-")
        }
        return parts.first ?? String(dirName)
    }
}
