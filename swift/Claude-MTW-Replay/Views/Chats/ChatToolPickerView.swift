import SwiftUI

/// G6 — header menu that lets the user pick which built-in tools the
/// running Claude agent may use. Toggling a row mutates the bound
/// `enabled` set and fires `onChange` so the host view can respawn the
/// agent with the new `--allowed-tools` argv.
///
/// `defaultTools` is the curated subset surfaced in the menu (full list
/// of SDK tools is longer; users who need exotic ones can still pass
/// them programmatically via `StartOptions.allowedTools`). The menu also
/// offers "Enable All" / "Disable All" shortcuts so the user can flip
/// the agent into a sandboxed (zero-tool) mode for read-only chat.
struct ChatToolPickerView: View {
    @Binding var enabled: Set<String>
    let onChange: () -> Void

    /// Curated list of built-in Claude tools shown in the picker. Kept
    /// in alphabetical-ish display order matching the SDK docs.
    static let defaultTools: [String] = [
        "Bash", "Read", "Edit", "Write", "Glob", "Grep",
        "WebFetch", "WebSearch", "NotebookEdit", "TodoWrite", "Task",
    ]

    var body: some View {
        Menu {
            Button("Enable All") {
                enabled = Set(Self.defaultTools)
                onChange()
            }
            Button("Disable All") {
                enabled = []
                onChange()
            }
            Divider()
            ForEach(Self.defaultTools, id: \.self) { tool in
                Button {
                    if enabled.contains(tool) {
                        enabled.remove(tool)
                    } else {
                        enabled.insert(tool)
                    }
                    onChange()
                } label: {
                    HStack {
                        Image(systemName: enabled.contains(tool) ? "checkmark.square.fill" : "square")
                        Text(tool)
                    }
                }
            }
        } label: {
            Label("Tools (\(enabled.count))", systemImage: "wrench.and.screwdriver")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Allow-list of tools Claude may invoke this session")
    }
}
