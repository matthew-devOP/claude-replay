import Foundation

// MARK: - Data types

/// A single session file with metadata.
struct SessionEntry: Identifiable, Codable {
    var id: String { sessionId }
    let sessionId: String
    let file: String
    let path: String
    let date: Date?
    let size: UInt64
}

/// A project containing one or more sessions.
struct ProjectEntry: Identifiable, Codable {
    var id: String { dirName }
    let source: String          // "claude", "cursor", "codex"
    let dirName: String
    let name: String            // human-readable
    let path: String            // real filesystem path (for Claude projects)
    let claudeProjectPath: String?
    let sessionCount: Int
    let lastActivity: Date?
}

/// A group of sessions from one tool (used by `discoverSessions`).
struct SessionGroup: Identifiable {
    var id: String { name }
    let name: String            // "Claude Code", "Cursor", "Codex CLI"
    var projects: [SessionProjectGroup]
}

/// One project's sessions inside a `SessionGroup`.
struct SessionProjectGroup: Identifiable {
    var id: String { dirName }
    let name: String
    let dirName: String
    var sessions: [SessionEntry]
}

/// Detailed project information including content files and aggregate stats.
struct ProjectDetails {
    let source: String
    let dirName: String
    let name: String
    let claudeProjectPath: String?
    let claudeMd: String?
    let memoryMd: String?
    let sessions: [SessionEntry]
    let stats: ProjectStats
}

struct ProjectStats: Codable {
    let totalSessions: Int
    let totalSize: UInt64
    let firstDate: Date?
    let lastDate: Date?
}

// MARK: - Discovery

/// Port of `discoverSessions`, `discoverProjects`, `getProjectDetails`, and
/// `claudeDirToProjectPath` from `editor-server.mjs`.
enum SessionDiscovery {

    private static let fm = FileManager.default

    /// Absolute URL to the current Claude account's `projects` directory.
    /// Defaults to `~/.claude/projects`; when `accountDir` is set (e.g. `.claude-work`)
    /// it points to `~/.claude-work/projects`.
    private static func claudeProjectsURL(accountDir: String) -> URL {
        fm.homeDirectoryURL.appendingPathComponent(accountDir).appendingPathComponent("projects")
    }

    // MARK: - claudeDirToProjectPath

    /// Reconstruct a real filesystem path from a Claude project directory name
    /// such as `-Users-joe-my-project`.  The algorithm greedily joins dash-
    /// separated parts, checking which segments exist on disk.
    static func claudeDirToProjectPath(_ dirName: String) -> String {
        let stripped = String(dirName.drop(while: { $0 == "-" }))
        let parts = stripped.split(separator: "-").map(String.init)

        var path = ""
        var i = 0
        while i < parts.count {
            var found = false
            for end in (i + 1)...parts.count {
                let segment = parts[i..<end].joined(separator: "-")
                let candidate = path + "/" + segment

                if end < parts.count {
                    // Not the last segment — accept only if it exists as a directory
                    if fm.isDirectory(at: candidate) {
                        path = candidate
                        i = end
                        found = true
                        break
                    }
                } else {
                    // Last segment — accept unconditionally
                    path = candidate
                    i = end
                    found = true
                    break
                }
            }
            if !found {
                path += "/" + parts[i]
                i += 1
            }
        }
        return path
    }

    // MARK: - discoverSessions

    /// Discover all sessions grouped by tool (Claude Code, Cursor, Codex CLI).
    /// Direct port of the JS `discoverSessions()`.
    static func discoverSessions(claudeAccountDir: String = ".claude") -> [SessionGroup] {
        let home = fm.homeDirectoryURL
        var groups: [SessionGroup] = []

        // ── Claude Code ─────────────────────────────────────────────────
        let claudeBase = claudeProjectsURL(accountDir: claudeAccountDir)
        let accountLabel: String = {
            if claudeAccountDir == ".claude" { return "Claude Code" }
            if claudeAccountDir.hasPrefix(".claude-") || claudeAccountDir.hasPrefix(".claude_") {
                return "Claude Code (\(claudeAccountDir.dropFirst(".claude-".count)))"
            }
            return "Claude Code (\(claudeAccountDir))"
        }()
        var claudeGroup = SessionGroup(name: accountLabel, projects: [])
        for proj in fm.sortedSubdirectories(at: claudeBase) {
            let projURL = claudeBase.appendingPathComponent(proj)
            let files = fm.jsonlFiles(in: projURL)
            guard !files.isEmpty else { continue }

            let sessions = files.map { file -> SessionEntry in
                let fullURL = projURL.appendingPathComponent(file)
                return SessionEntry(
                    sessionId: String(file.dropLast(6)),
                    file: file,
                    path: fullURL.path,
                    date: fm.modificationDate(of: fullURL),
                    size: fm.fileSize(of: fullURL)
                )
            }
            claudeGroup.projects.append(SessionProjectGroup(
                name: SessionResolver.displayName(from: proj),
                dirName: proj,
                sessions: sessions
            ))
        }
        if !claudeGroup.projects.isEmpty { groups.append(claudeGroup) }

        // ── Cursor ──────────────────────────────────────────────────────
        let cursorBase = home.appendingPathComponent(".cursor/projects")
        var cursorGroup = SessionGroup(name: "Cursor", projects: [])
        for proj in fm.sortedSubdirectories(at: cursorBase) {
            let transcriptsDir = cursorBase
                .appendingPathComponent(proj)
                .appendingPathComponent("agent-transcripts")
            let ids = fm.sortedSubdirectories(at: transcriptsDir).reversed()
            var cursorSessions: [SessionEntry] = []

            for id in ids {
                let idDir = transcriptsDir.appendingPathComponent(id)
                let candidate1 = idDir.appendingPathComponent("transcript.jsonl")
                let candidate2 = idDir.appendingPathComponent(id + ".jsonl")

                let filePath: URL
                if fm.isRegularFile(at: candidate1) {
                    filePath = candidate1
                } else if fm.isRegularFile(at: candidate2) {
                    filePath = candidate2
                } else {
                    continue
                }

                cursorSessions.append(SessionEntry(
                    sessionId: id,
                    file: id,
                    path: filePath.path,
                    date: fm.modificationDate(of: filePath),
                    size: fm.fileSize(of: filePath)
                ))
            }
            guard !cursorSessions.isEmpty else { continue }
            cursorGroup.projects.append(SessionProjectGroup(
                name: SessionResolver.displayName(from: proj),
                dirName: proj,
                sessions: cursorSessions
            ))
        }
        if !cursorGroup.projects.isEmpty { groups.append(cursorGroup) }

        // ── Codex CLI ───────────────────────────────────────────────────
        let codexBase = home.appendingPathComponent(".codex/sessions")
        var codexGroup = SessionGroup(name: "Codex CLI", projects: [])
        for year in fm.sortedSubdirectories(at: codexBase).reversed() {
            let yearURL = codexBase.appendingPathComponent(year)
            for month in fm.sortedSubdirectories(at: yearURL).reversed() {
                let monthURL = yearURL.appendingPathComponent(month)
                for day in fm.sortedSubdirectories(at: monthURL).reversed() {
                    let dayURL = monthURL.appendingPathComponent(day)
                    let files = fm.jsonlFiles(in: dayURL)
                    guard !files.isEmpty else { continue }

                    let sessions = files.map { file -> SessionEntry in
                        let fullURL = dayURL.appendingPathComponent(file)
                        return SessionEntry(
                            sessionId: String(file.dropLast(6)),
                            file: file,
                            path: fullURL.path,
                            date: fm.modificationDate(of: fullURL),
                            size: fm.fileSize(of: fullURL)
                        )
                    }
                    codexGroup.projects.append(SessionProjectGroup(
                        name: "\(year)-\(month)-\(day)",
                        dirName: "\(year)/\(month)/\(day)",
                        sessions: sessions
                    ))
                }
            }
        }
        if !codexGroup.projects.isEmpty { groups.append(codexGroup) }

        return groups
    }

    // MARK: - discoverProjects

    /// Discover projects from all tools (Claude Code, Cursor, Codex CLI) with
    /// aggregate metadata.
    static func discoverProjects(claudeAccountDir: String = ".claude") -> [ProjectEntry] {
        let home = fm.homeDirectoryURL
        var projects: [ProjectEntry] = []

        // ── Claude Code ──────────────────────────────────────────────────
        let claudeBase = claudeProjectsURL(accountDir: claudeAccountDir)
        for dir in fm.sortedSubdirectories(at: claudeBase) {
            let projURL = claudeBase.appendingPathComponent(dir)
            let files = fm.jsonlFiles(in: projURL)
            guard !files.isEmpty else { continue }

            var lastActivity: Date?
            for file in files {
                if let mtime = fm.modificationDate(of: projURL.appendingPathComponent(file)) {
                    if lastActivity == nil || mtime > lastActivity! { lastActivity = mtime }
                }
            }

            let realPath = claudeDirToProjectPath(dir)
            let displayName = URL(fileURLWithPath: realPath).lastPathComponent

            projects.append(ProjectEntry(
                source: "claude",
                dirName: dir,
                name: displayName,
                path: realPath,
                claudeProjectPath: projURL.path,
                sessionCount: files.count,
                lastActivity: lastActivity
            ))
        }

        // ── Cursor ───────────────────────────────────────────────────────
        let cursorBase = home.appendingPathComponent(".cursor/projects")
        for dir in fm.sortedSubdirectories(at: cursorBase) {
            let transcriptsDir = cursorBase
                .appendingPathComponent(dir)
                .appendingPathComponent("agent-transcripts")
            let sessionDirs = fm.sortedSubdirectories(at: transcriptsDir)
            guard !sessionDirs.isEmpty else { continue }

            var lastActivity: Date?
            var sessionCount = 0
            for id in sessionDirs {
                let idDir = transcriptsDir.appendingPathComponent(id)
                let candidate1 = idDir.appendingPathComponent("transcript.jsonl")
                let candidate2 = idDir.appendingPathComponent(id + ".jsonl")
                let filePath = fm.isRegularFile(at: candidate1) ? candidate1
                             : fm.isRegularFile(at: candidate2) ? candidate2
                             : nil
                guard let filePath else { continue }
                sessionCount += 1
                if let mtime = fm.modificationDate(of: filePath) {
                    if lastActivity == nil || mtime > lastActivity! { lastActivity = mtime }
                }
            }
            guard sessionCount > 0 else { continue }

            let realPath = claudeDirToProjectPath(dir)
            let displayName = URL(fileURLWithPath: realPath).lastPathComponent

            projects.append(ProjectEntry(
                source: "cursor",
                dirName: dir,
                name: displayName,
                path: realPath,
                claudeProjectPath: nil,
                sessionCount: sessionCount,
                lastActivity: lastActivity
            ))
        }

        // ── Codex CLI ────────────────────────────────────────────────────
        let codexBase = home.appendingPathComponent(".codex/sessions")
        for year in fm.sortedSubdirectories(at: codexBase).reversed() {
            let yearURL = codexBase.appendingPathComponent(year)
            for month in fm.sortedSubdirectories(at: yearURL).reversed() {
                let monthURL = yearURL.appendingPathComponent(month)
                for day in fm.sortedSubdirectories(at: monthURL).reversed() {
                    let dayURL = monthURL.appendingPathComponent(day)
                    let files = fm.jsonlFiles(in: dayURL)
                    guard !files.isEmpty else { continue }

                    var lastActivity: Date?
                    for file in files {
                        if let mtime = fm.modificationDate(of: dayURL.appendingPathComponent(file)) {
                            if lastActivity == nil || mtime > lastActivity! { lastActivity = mtime }
                        }
                    }

                    let dirName = "\(year)/\(month)/\(day)"
                    projects.append(ProjectEntry(
                        source: "codex",
                        dirName: dirName,
                        name: "\(year)-\(month)-\(day)",
                        path: dayURL.path,
                        claudeProjectPath: nil,
                        sessionCount: files.count,
                        lastActivity: lastActivity
                    ))
                }
            }
        }

        // Sort by last activity descending
        projects.sort { ($0.lastActivity ?? .distantPast) > ($1.lastActivity ?? .distantPast) }
        return projects
    }

    // MARK: - getProjectDetails

    /// Get detailed project information including CLAUDE.md, MEMORY.md, and
    /// session metadata.  Direct port of the JS `getProjectDetails()`.
    static func getProjectDetails(source: String, dirName: String, claudeAccountDir: String = ".claude") -> ProjectDetails? {
        guard source == "claude" else { return nil }

        let projURL = claudeProjectsURL(accountDir: claudeAccountDir).appendingPathComponent(dirName)
        guard fm.isDirectory(at: projURL.path) else { return nil }

        let realPath = claudeDirToProjectPath(dirName)

        // Read CLAUDE.md from the actual project directory
        let claudeMdPath = realPath + "/CLAUDE.md"
        let claudeMd = try? String(contentsOfFile: claudeMdPath, encoding: .utf8)

        // Read MEMORY.md from the claude project directory
        let memoryMdPath = projURL
            .appendingPathComponent("memory")
            .appendingPathComponent("MEMORY.md")
            .path
        let memoryMd = try? String(contentsOfFile: memoryMdPath, encoding: .utf8)

        // List sessions
        let files = fm.jsonlFiles(in: projURL)
        var sessions: [SessionEntry] = []
        var totalSize: UInt64 = 0
        var dates: [Date] = []

        for file in files {
            let fullURL = projURL.appendingPathComponent(file)
            let date = fm.modificationDate(of: fullURL)
            let size = fm.fileSize(of: fullURL)
            totalSize += size
            if let d = date { dates.append(d) }

            sessions.append(SessionEntry(
                sessionId: String(file.dropLast(6)),
                file: file,
                path: fullURL.path,
                date: date,
                size: size
            ))
        }

        dates.sort()
        let stats = ProjectStats(
            totalSessions: sessions.count,
            totalSize: totalSize,
            firstDate: dates.first,
            lastDate: dates.last
        )

        return ProjectDetails(
            source: source,
            dirName: dirName,
            name: realPath,
            claudeProjectPath: projURL.path,
            claudeMd: claudeMd,
            memoryMd: memoryMd,
            sessions: sessions,
            stats: stats
        )
    }
}
