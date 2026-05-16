import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("defaultTheme") private var defaultTheme = "tokyo-night"
    @AppStorage("defaultSpeed") private var defaultSpeed = 1.0
    @AppStorage("showThinkingByDefault") private var showThinking = true
    @AppStorage("showToolCallsByDefault") private var showTools = true
    @AppStorage("autoRedactSecrets") private var autoRedact = true
    @AppStorage("toolGroupThreshold") private var toolGroupThreshold: Int = 5
    @AppStorage("defaultOGImageURL") private var defaultOGImageURL: String = ""
    @AppStorage("telemetryOptIn") private var telemetryOptIn: Bool = false
    @AppStorage("telemetryAnonymousId") private var anonymousId: String = ""

    @State private var nodePath: String? = SettingsView.resolve { try SidecarLocator.nodeBinary() }
    @State private var claudePath: String? = SettingsView.resolve { try SidecarLocator.claudeBinary() }
    @State private var customThemePaths: [String] = ThemeService.customThemePaths()
    @State private var customThemeReloadMessage: String?

    var body: some View {
        Form {
            Section("Playback") {
                Picker("Default Theme", selection: $defaultTheme) {
                    ForEach(ThemeService.listThemes(), id: \.self) { Text($0).tag($0) }
                }
                Picker("Speed", selection: $defaultSpeed) {
                    ForEach(ReplayViewModel.speedSteps, id: \.self) { step in
                        Text("\(step, specifier: step == Double(Int(step)) ? "%.0f" : "%.1f")x").tag(step)
                    }
                }
                Toggle("Show thinking blocks", isOn: $showThinking)
                Toggle("Show tool calls", isOn: $showTools)
            }
            Section("Security") {
                Toggle("Auto-redact secrets", isOn: $autoRedact)
            }
            Section("Display") {
                Stepper(
                    "Tool grouping threshold: \(toolGroupThreshold)",
                    value: $toolGroupThreshold,
                    in: 1...20
                )
                .help("Group N or more consecutive tool calls into a collapsible block.")
                LabeledContent("Default OG image URL") {
                    TextField(
                        "https://example.com/og.png",
                        text: $defaultOGImageURL,
                        prompt: Text("https://es617.github.io/claude-replay/og.png")
                    )
                    .textFieldStyle(.roundedBorder)
                }
                .help("Fallback Open Graph image used for HTML exports when the export doesn't set one.")
            }
            Section("Custom Themes") {
                if customThemePaths.isEmpty {
                    Text("No custom themes imported.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(customThemePaths, id: \.self) { path in
                        HStack(spacing: 8) {
                            Image(systemName: "paintpalette")
                                .foregroundStyle(.secondary)
                            Text((path as NSString).lastPathComponent)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button("Remove", role: .destructive) {
                                removeCustomTheme(path)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                HStack(spacing: 8) {
                    Button("Import…") { importCustomTheme() }
                    Button("Reload from disk") { reloadCustomThemes() }
                    if let msg = customThemeReloadMessage {
                        Text(msg)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            Section("Privacy & Diagnostics") {
                Toggle("Send anonymous usage statistics", isOn: telemetryBinding)
                    .help("Tracks tab switches, export clicks, and chat starts to help us improve the app. No content or identifying data is sent.")
                LabeledContent("Anonymous ID") {
                    Text(anonymousIdLabel).font(.caption).foregroundStyle(.secondary)
                }
                LabeledContent("Crash reporting") {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("MetricKit active (system-managed)")
                    }
                }
                Text("View privacy policy at https://es617.github.io/claude-mtw-replay/privacy")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("MCP Servers") {
                MCPServersSettingsView()
            }
            Section("Sidecar") {
                LabeledContent("Node binary") {
                    HStack(spacing: 8) {
                        statusIcon(found: nodePath != nil)
                        Text(nodePath ?? "Not located")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("Locate…") { locate(.node) }
                    }
                }
                LabeledContent("Claude binary") {
                    HStack(spacing: 8) {
                        statusIcon(found: claudePath != nil)
                        Text(claudePath ?? "Not located")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("Locate…") { locate(.claude) }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
    }

    @ViewBuilder
    private func statusIcon(found: Bool) -> some View {
        if found {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        } else {
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }

    private enum BinaryKind { case node, claude }

    private func locate(_ kind: BinaryKind) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.unixExecutable, .executable, .item]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.treatsFilePackagesAsDirectories = true
        panel.directoryURL = URL(fileURLWithPath: "/usr/local/bin")
        panel.prompt = "Select"
        if panel.runModal() == .OK, let url = panel.url {
            switch kind {
            case .node:
                SidecarLocator.setNodeBinary(url)
                nodePath = url.path
            case .claude:
                SidecarLocator.setClaudeBinary(url)
                claudePath = url.path
            }
        }
    }

    private static func resolve(_ block: () throws -> URL) -> String? {
        (try? block())?.path
    }

    // MARK: - Privacy & Diagnostics helpers

    private var telemetryBinding: Binding<Bool> {
        Binding(get: { telemetryOptIn }, set: { telemetryOptIn = $0 })
    }
    private var anonymousIdLabel: String {
        anonymousId.isEmpty ? "(not yet generated)" : "\(anonymousId.prefix(8))…"
    }

    // MARK: - Custom theme actions

    private func importCustomTheme() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Import"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        ThemeService.addCustomThemePath(url.path)
        customThemePaths = ThemeService.customThemePaths()
        customThemeReloadMessage = "Imported \(url.lastPathComponent)"
    }

    private func removeCustomTheme(_ path: String) {
        ThemeService.removeCustomThemePath(path)
        customThemePaths = ThemeService.customThemePaths()
        customThemeReloadMessage = nil
    }

    private func reloadCustomThemes() {
        let loaded = ThemeService.reloadFromDisk()
        customThemePaths = ThemeService.customThemePaths()
        customThemeReloadMessage = "Reloaded \(loaded.count) theme\(loaded.count == 1 ? "" : "s")"
    }
}
