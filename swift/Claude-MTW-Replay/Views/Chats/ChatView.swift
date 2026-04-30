import SwiftUI

/// Live conversation view — wires the Resume action to the Claude agent
/// sidecar, renders streaming turns, and hosts the input bar with mode
/// toggles and prefix buttons.
///
/// This is a placeholder for steps 4–10 of the v0.8.0-swift plan. Right
/// now it just shows the session id; ClaudeAgent + ChatViewModel arrive
/// in steps 4–6, the live transcript in step 7, the input bar in step 8.
struct ChatView: View {
    @Environment(\.dismiss) private var dismiss
    let sessionPath: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "bubble.left.and.exclamationmark.bubble.right")
                Text("Resuming")
                    .font(.headline)
                Text(URL(fileURLWithPath: sessionPath).lastPathComponent)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)
            Divider()
            VStack(spacing: 12) {
                Image(systemName: "ellipsis.bubble")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                Text("Live chat is being wired up.")
                    .font(.headline)
                Text("ClaudeAgent + streaming arrive in steps 4–8 of the v0.8.0-swift plan.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
