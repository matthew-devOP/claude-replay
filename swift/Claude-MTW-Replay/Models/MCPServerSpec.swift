import Foundation

/// G3 — User-configured MCP (Model Context Protocol) server entry.
///
/// Persisted as JSON in `UserDefaults` via `MCPServerStore` and serialised
/// to the sidecar as an entry inside the SDK's
/// `options.mcpServers: Record<string, McpServerConfig>` dict. Today we
/// only model the stdio config shape (`command` / `args` / `env`), which is
/// what `claude-agent-sdk` expects for locally-spawned MCP servers.
struct MCPServerSpec: Identifiable, Codable, Hashable {
    var id: String { name }
    var name: String
    var command: String  // executable path or command name
    var args: [String]
    var env: [String: String]
    var enabled: Bool

    init(
        name: String,
        command: String,
        args: [String] = [],
        env: [String: String] = [:],
        enabled: Bool = true
    ) {
        self.name = name
        self.command = command
        self.args = args
        self.env = env
        self.enabled = enabled
    }
}
