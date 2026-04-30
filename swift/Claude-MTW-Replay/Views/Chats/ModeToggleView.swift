import SwiftUI

/// Three-chip permission-mode picker. Mirrors the chips Claude Code shows
/// in its TUI (Plan / Accept Edits / Default) plus the SDK-only
/// `bypassPermissions` mode hidden behind a long-press for safety.
///
/// Selecting a different mode calls `onChange` which kicks off a respawn
/// in `ChatViewModel.changeMode(...)`. We don't try to live-toggle: the
/// SDK applies `permissionMode` at session start.
struct ModeToggleView: View {
    @Environment(AppState.self) private var appState

    let currentMode: String
    let onChange: (String) -> Void

    /// User-visible modes. `bypassPermissions` is intentionally omitted
    /// from the chip row — surface it via Settings if needed.
    private static let modes: [Mode] = [
        Mode(id: "plan",          label: "Plan",        icon: "list.bullet.rectangle",  help: "Read-only mode — Claude proposes changes but doesn't apply them"),
        Mode(id: "acceptEdits",   label: "Accept Edits", icon: "checkmark.shield",       help: "Auto-approve file edits without prompting"),
        Mode(id: "default",       label: "Default",      icon: "shield",                 help: "Standard prompt-for-permission behaviour"),
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Self.modes) { mode in
                Button {
                    onChange(mode.id)
                } label: {
                    Label(mode.label, systemImage: mode.icon)
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(currentMode == mode.id ? appState.theme.accent : .secondary)
                .help(mode.help)
            }
        }
    }

    private struct Mode: Identifiable {
        let id: String
        let label: String
        let icon: String
        let help: String
    }
}
