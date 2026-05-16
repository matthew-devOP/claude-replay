import Foundation

/// Discovery + load for Claude Code style `/commands`. Scans the
/// per-project `.claude/commands/` first then the per-account
/// `~/<claudeAccountDir>/commands/` so a project command shadows a
/// user-level command with the same name.
enum SlashCommandService {
    /// Discover slash commands in `<projectPath>/.claude/commands/`
    /// and `~/<claudeAccountDir>/commands/`. Project commands take
    /// precedence over user-level ones when names collide.
    static func discover(projectPath: String?, claudeAccountDir: String) -> [SlashCommand] {
        var all: [SlashCommand] = []
        if let project = projectPath {
            let projectCmdDir = (project as NSString).appendingPathComponent(".claude/commands")
            all.append(contentsOf: load(dir: projectCmdDir, source: .project))
        }
        let homeCmdDir = ((NSHomeDirectory() as NSString).appendingPathComponent(claudeAccountDir) as NSString).appendingPathComponent("commands")
        all.append(contentsOf: load(dir: homeCmdDir, source: .user))
        // Dedupe by name preferring project source (first occurrence wins
        // because project commands were appended first).
        var seen: Set<String> = []
        return all.filter { cmd in
            if seen.contains(cmd.name) { return false }
            seen.insert(cmd.name)
            return true
        }
    }

    private static func load(dir: String, source: SlashCommand.Source) -> [SlashCommand] {
        guard FileManager.default.fileExists(atPath: dir) else { return [] }
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return [] }
        return files.compactMap { fname -> SlashCommand? in
            guard fname.hasSuffix(".md") else { return nil }
            let url = URL(fileURLWithPath: (dir as NSString).appendingPathComponent(fname))
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            let id = (fname as NSString).deletingPathExtension
            let (frontMatter, body) = parseFrontMatter(content)
            return SlashCommand(
                id: id,
                name: frontMatter["name"] ?? id,
                description: frontMatter["description"],
                body: body,
                source: source,
                url: url
            )
        }
    }

    /// Parse a minimal YAML-ish front-matter block. Only `key: value`
    /// scalars on single lines are recognised — enough for the `name`
    /// and `description` fields expected by Claude Code commands.
    private static func parseFrontMatter(_ content: String) -> ([String: String], String) {
        var meta: [String: String] = [:]
        var body = content
        if content.hasPrefix("---\n") {
            let rest = String(content.dropFirst(4))
            if let endRange = rest.range(of: "\n---\n") {
                let frontText = String(rest[..<endRange.lowerBound])
                body = String(rest[endRange.upperBound...])
                for line in frontText.split(separator: "\n") {
                    let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                    if parts.count == 2 { meta[parts[0]] = parts[1] }
                }
            }
        }
        return (meta, body.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
