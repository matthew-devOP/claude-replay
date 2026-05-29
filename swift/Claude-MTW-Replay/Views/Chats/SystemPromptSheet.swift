import SwiftUI

/// G5 — Sheet for editing the per-conversation system-prompt override.
///
/// The text is appended to the SDK's default system prompt; the toggles
/// fold the project/account CLAUDE.md and MEMORY.md into that addendum
/// (see `ChatViewModel.effectiveSystemPrompt()`). Pressing "Apply" mutates
/// the `ChatViewModel` and respawns the sidecar so the new prompt takes
/// effect immediately.
struct SystemPromptSheet: View {
    @Bindable var vm: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var localPrompt: String = ""
    @State private var localIncludeClaudeMd: Bool = true
    @State private var localIncludeMemoryMd: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.space12) {
            HStack {
                Text("System Prompt Override").font(.headline)
                Spacer()
                Button {
                    appState.showDoc(topicId: "chats")
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Open chats documentation")
            }
            Text("Appended to the SDK's default system prompt")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $localPrompt)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.secondary.opacity(0.3), lineWidth: 1)
                )
            Toggle("Include CLAUDE.md context", isOn: $localIncludeClaudeMd)
            Toggle("Include MEMORY.md context", isOn: $localIncludeMemoryMd)
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Apply") {
                    vm.systemPromptOverride = localPrompt.isEmpty ? nil : localPrompt
                    vm.includeClaudeMd = localIncludeClaudeMd
                    vm.includeMemoryMd = localIncludeMemoryMd
                    Task {
                        await vm.respawnWithNewOptions()
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(DesignTokens.space20)
        .frame(width: 500, height: 400)
        .onAppear {
            localPrompt = vm.systemPromptOverride ?? ""
            localIncludeClaudeMd = vm.includeClaudeMd
            localIncludeMemoryMd = vm.includeMemoryMd
        }
    }
}
