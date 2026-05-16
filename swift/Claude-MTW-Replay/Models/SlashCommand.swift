import Foundation

/// Represents a `/command` discovered in `<project>/.claude/commands/*.md`
/// or `~/.claude/commands/*.md`. Mirrors the Claude Code TUI behaviour:
/// the file is plain Markdown with an optional YAML-style front-matter
/// block (`---\nname: ...\ndescription: ...\n---`) followed by the body.
/// `$ARGUMENTS` inside the body is substituted at expansion time.
struct SlashCommand: Identifiable, Hashable {
    let id: String  // file stem, e.g. "review"
    let name: String  // same as id
    let description: String?
    let body: String  // raw markdown without front-matter
    let source: Source
    let url: URL

    enum Source: String { case project, user, builtin }

    /// Expand the `$ARGUMENTS` placeholder with the provided text.
    /// If the placeholder is absent the body is returned unchanged so
    /// argument-less commands "just work".
    func expanded(args: String) -> String {
        return body.replacingOccurrences(of: "$ARGUMENTS", with: args)
    }
}
