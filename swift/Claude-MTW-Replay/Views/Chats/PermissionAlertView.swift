import SwiftUI

/// G8 — modal presented via `.sheet(item: $vm.pendingPermission)` whenever
/// the sidecar's `canUseTool` callback fires for a tool input we don't yet
/// have a cached decision for. The user picks Allow / Deny and an optional
/// "remember" scope; the parent view forwards the pick to
/// `ChatViewModel.respondPermission(allow:remember:)`.
///
/// Layout is deliberately compact (480 pt wide, ~3 rows) so it fits on
/// laptop screens without scrolling and doesn't dominate the chat. The
/// summary is intentionally not truncated — denying a Bash command you
/// can't see the full text of would be a security footgun.
struct PermissionAlertView: View {
    let request: PermissionRequest
    let onDecide: (Bool, PermissionRemember) -> Void

    @State private var remember: PermissionRemember = .once

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.space12) {
            HStack(spacing: DesignTokens.space8) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.tint)
                Text("Permission requested")
                    .font(.headline)
            }

            Text(request.toolInputSummary)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(DesignTokens.space8)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: DesignTokens.cornerSmall))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Tool: \(request.toolName)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Remember", selection: $remember) {
                Text("Just this once").tag(PermissionRemember.once)
                Text("Always for this signature").tag(PermissionRemember.always)
            }
            .pickerStyle(.segmented)

            HStack {
                Button("Deny") {
                    onDecide(false, remember)
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Allow") {
                    onDecide(true, remember)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(DesignTokens.space20)
        .frame(width: 480)
    }
}

#Preview {
    PermissionAlertView(
        request: PermissionRequest(
            toolName: "Bash",
            toolInputSummary: "ls -la /etc",
            signature: "abc123",
            requestId: "req_1"
        ),
        onDecide: { _, _ in }
    )
}
