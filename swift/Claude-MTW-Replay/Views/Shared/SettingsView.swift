import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("defaultTheme") private var defaultTheme = "tokyo-night"
    @AppStorage("defaultSpeed") private var defaultSpeed = 1.0
    @AppStorage("showThinkingByDefault") private var showThinking = true
    @AppStorage("showToolCallsByDefault") private var showTools = true
    @AppStorage("autoRedactSecrets") private var autoRedact = true

    @State private var nodePath: String? = SettingsView.resolve { try SidecarLocator.nodeBinary() }
    @State private var claudePath: String? = SettingsView.resolve { try SidecarLocator.claudeBinary() }

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
}
