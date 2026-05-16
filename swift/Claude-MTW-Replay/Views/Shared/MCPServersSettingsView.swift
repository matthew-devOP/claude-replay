import SwiftUI

/// G3 — Settings panel for managing MCP (Model Context Protocol) servers.
///
/// Lists every spec from `MCPServerStore`, lets the user toggle each one
/// on/off, delete entries, and open `MCPServerEditSheet` to add a new
/// server. Changes are persisted back to `MCPServerStore` immediately so
/// the next chat start picks them up via `activeServers()`.
struct MCPServersSettingsView: View {
    @State private var servers: [MCPServerSpec] = []
    @State private var showAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Configured Servers").font(.headline)
                Spacer()
                Button("Add Server…") { showAddSheet = true }
            }
            if servers.isEmpty {
                Text("No MCP servers configured")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach($servers) { $server in
                    HStack(alignment: .top, spacing: 8) {
                        Toggle("", isOn: $server.enabled).labelsHidden()
                        VStack(alignment: .leading, spacing: 2) {
                            Text(server.name).font(.body)
                            Text("\(server.command) \(server.args.joined(separator: " "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button {
                            servers.removeAll { $0.id == server.id }
                            MCPServerStore.shared.save(servers)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                        .help("Remove this server")
                    }
                    .onChange(of: server.enabled) { _, _ in
                        MCPServerStore.shared.save(servers)
                    }
                }
            }
        }
        .task { servers = MCPServerStore.shared.load() }
        .sheet(isPresented: $showAddSheet) {
            MCPServerEditSheet { newServer in
                servers.removeAll { $0.name == newServer.name }
                servers.append(newServer)
                MCPServerStore.shared.save(servers)
            }
        }
    }
}

/// G3 — Modal form for adding a new MCP server spec. Validation is
/// intentionally minimal: just non-empty `name` and `command`. The args
/// field is space-separated; env is `KEY=VALUE` per line.
struct MCPServerEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (MCPServerSpec) -> Void

    @State private var name: String = ""
    @State private var command: String = ""
    @State private var argsString: String = ""
    @State private var envString: String = ""  // KEY=VALUE per line

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add MCP Server").font(.headline)
            Form {
                TextField("Name (unique)", text: $name)
                TextField("Command (e.g. /usr/local/bin/uvx)", text: $command)
                TextField("Args (space-separated)", text: $argsString)
                TextField("Env (KEY=VALUE per line)", text: $envString, axis: .vertical)
                    .lineLimit(3...6)
            }
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Add") {
                    let args = argsString
                        .split(separator: " ")
                        .map(String.init)
                        .filter { !$0.isEmpty }
                    var env: [String: String] = [:]
                    for line in envString.split(separator: "\n") {
                        let parts = line.split(separator: "=", maxSplits: 1)
                        if parts.count == 2 {
                            let k = String(parts[0]).trimmingCharacters(in: .whitespaces)
                            let v = String(parts[1]).trimmingCharacters(in: .whitespaces)
                            if !k.isEmpty { env[k] = v }
                        }
                    }
                    let server = MCPServerSpec(name: name, command: command, args: args, env: env)
                    onSave(server)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || command.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 500)
    }
}
