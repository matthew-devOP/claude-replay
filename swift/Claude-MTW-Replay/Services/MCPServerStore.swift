import Foundation

/// G3 — Persistent store for user-configured MCP servers.
///
/// Backed by `UserDefaults` (a single JSON blob under the `mcpServers`
/// key). The store is intentionally tiny: load + save + add/remove
/// helpers, plus `activeServers()` that materialises the enabled subset
/// as a `[String: [String: Any]]` dict ready to drop into
/// `ClaudeAgent.StartOptions.mcpServers`.
///
/// `@MainActor` because the settings UI and `ChatViewModel.start()` both
/// touch it from the main actor.
@MainActor
final class MCPServerStore {
    static let shared = MCPServerStore()
    private let key = "mcpServers"

    func load() -> [MCPServerSpec] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([MCPServerSpec].self, from: data) else {
            return []
        }
        return decoded
    }

    func save(_ servers: [MCPServerSpec]) {
        if let data = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func add(_ server: MCPServerSpec) {
        var current = load()
        current.removeAll { $0.name == server.name }
        current.append(server)
        save(current)
    }

    func remove(name: String) {
        var current = load()
        current.removeAll { $0.name == name }
        save(current)
    }

    /// Returns active (enabled) servers as a dict ready for the SDK options.
    /// Shape matches the SDK's `McpStdioServerConfig`: `{command, args?, env?}`.
    func activeServers() -> [String: [String: Any]] {
        var dict: [String: [String: Any]] = [:]
        for server in load() where server.enabled {
            var spec: [String: Any] = ["command": server.command]
            if !server.args.isEmpty { spec["args"] = server.args }
            if !server.env.isEmpty { spec["env"] = server.env }
            dict[server.name] = spec
        }
        return dict
    }
}
