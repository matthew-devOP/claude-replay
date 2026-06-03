import Foundation

enum SearchService {
    static func search(query: String, in projectDirName: String, maxFiles: Int = 30, maxResults: Int = 50) -> [SearchResult] {
        let fm = FileManager.default
        let projDir = fm.homeDirectoryURL.appendingPathComponent(".claude/projects/\(projectDirName)")
        let files = fm.jsonlFiles(in: projDir).prefix(maxFiles)
        var results: [SearchResult] = []
        let lowerQuery = query.lowercased()

        for file in files {
            let path = projDir.appendingPathComponent(file)
            guard let text = try? String(contentsOf: path, encoding: .utf8) else { continue }
            let turns = TranscriptParser.parseTranscriptFromText(text)
            for turn in turns {
                let strippedUserText = turn.userText.replacingOccurrences(
                    of: #"<system-reminder>[\s\S]*?</system-reminder>"#,
                    with: "",
                    options: [.regularExpression]
                )
                if strippedUserText.lowercased().contains(lowerQuery) {
                    results.append(SearchResult(id: UUID(), projectName: projectDirName, sessionPath: path.path, turnIndex: turn.index, matchText: String(strippedUserText.prefix(200)), role: "User", context: ""))
                }
                for block in turn.blocks where block.text.lowercased().contains(lowerQuery) {
                    results.append(SearchResult(id: UUID(), projectName: projectDirName, sessionPath: path.path, turnIndex: turn.index, matchText: String(block.text.prefix(200)), role: block.kind.rawValue, context: ""))
                }
                if results.count >= maxResults { return results }
            }
        }
        return results
    }

    /// Search across all discovered projects — Claude Code, Cursor, **and**
    /// Codex CLI sessions. P1.3 (docs/IMPROVEMENTS_SWIFT.md lines 184-188).
    ///
    /// Iterates over `SessionDiscovery.discoverSessions(claudeAccountDir:)`,
    /// which already enumerates every session file across the three
    /// supported sources, and searches their parsed turns directly. The
    /// previous implementation only walked the Claude `projects/` tree.
    static func searchAllProjects(query: String, maxResults: Int = 50, claudeAccountDir: String = ".claude") -> [SearchResult] {
        // ALL mode: give every account its own budget, then interleave
        // round-robin so a single noisy account can't crowd the results.
        if claudeAccountDir == AccountStore.allDirName {
            let accountDirs = AccountStore.realAccountDirs()
            let perAccount = max(1, Int((Double(maxResults) / Double(max(1, accountDirs.count))).rounded(.up)))
            let perAccountResults: [[SearchResult]] = accountDirs.map { dir in
                searchClaudeAccount(query: query, accountDir: dir, maxResults: perAccount)
            }
            // Round-robin interleave up to the global cap.
            var results: [SearchResult] = []
            var idx = 0
            while results.count < maxResults {
                var addedThisRound = false
                for list in perAccountResults where idx < list.count {
                    results.append(list[idx])
                    addedThisRound = true
                    if results.count >= maxResults { break }
                }
                if !addedThisRound { break }
                idx += 1
            }
            return results
        }

        let groups = SessionDiscovery.discoverSessions(claudeAccountDir: claudeAccountDir)
        var results: [SearchResult] = []
        let lowerQuery = query.lowercased()

        outer: for group in groups {
            for project in group.projects {
                // Project label combines the source group + project name so
                // result rows make sense across mixed tools.
                let projectLabel = "\(group.name) · \(project.name)"
                for session in project.sessions {
                    guard let text = try? String(contentsOfFile: session.path, encoding: .utf8) else { continue }
                    let turns = TranscriptParser.parseTranscriptFromText(text)
                    for turn in turns {
                        let strippedUserText = turn.userText.replacingOccurrences(
                            of: #"<system-reminder>[\s\S]*?</system-reminder>"#,
                            with: "",
                            options: [.regularExpression]
                        )
                        if strippedUserText.lowercased().contains(lowerQuery) {
                            results.append(SearchResult(
                                id: UUID(),
                                projectName: projectLabel,
                                sessionPath: session.path,
                                turnIndex: turn.index,
                                matchText: String(strippedUserText.prefix(200)),
                                role: "User",
                                context: ""
                            ))
                        }
                        for block in turn.blocks where block.text.lowercased().contains(lowerQuery) {
                            results.append(SearchResult(
                                id: UUID(),
                                projectName: projectLabel,
                                sessionPath: session.path,
                                turnIndex: turn.index,
                                matchText: String(block.text.prefix(200)),
                                role: block.kind.rawValue,
                                context: ""
                            ))
                        }
                        if results.count >= maxResults { break outer }
                    }
                }
            }
        }
        return results
    }

    /// Search only the Claude Code sessions belonging to ONE account, tagging
    /// each result with that account's label. Used by the ALL-mode interleave.
    private static func searchClaudeAccount(query: String, accountDir: String, maxResults: Int) -> [SearchResult] {
        let label = ClaudeAccount(dirName: accountDir).label
        let groups = SessionDiscovery.discoverSessions(claudeAccountDir: accountDir)
        var results: [SearchResult] = []
        let lowerQuery = query.lowercased()

        outer: for group in groups where group.name.hasPrefix("Claude") {
            for project in group.projects {
                let projectLabel = "\(group.name) · \(project.name)"
                for session in project.sessions {
                    guard let text = try? String(contentsOfFile: session.path, encoding: .utf8) else { continue }
                    let turns = TranscriptParser.parseTranscriptFromText(text)
                    for turn in turns {
                        let strippedUserText = turn.userText.replacingOccurrences(
                            of: #"<system-reminder>[\s\S]*?</system-reminder>"#,
                            with: "",
                            options: [.regularExpression]
                        )
                        if strippedUserText.lowercased().contains(lowerQuery) {
                            results.append(SearchResult(
                                projectName: projectLabel,
                                sessionPath: session.path,
                                turnIndex: turn.index,
                                matchText: String(strippedUserText.prefix(200)),
                                role: "User",
                                context: "",
                                accountLabel: label
                            ))
                        }
                        for block in turn.blocks where block.text.lowercased().contains(lowerQuery) {
                            results.append(SearchResult(
                                projectName: projectLabel,
                                sessionPath: session.path,
                                turnIndex: turn.index,
                                matchText: String(block.text.prefix(200)),
                                role: block.kind.rawValue,
                                context: "",
                                accountLabel: label
                            ))
                        }
                        if results.count >= maxResults { break outer }
                    }
                }
            }
        }
        return results
    }
}
