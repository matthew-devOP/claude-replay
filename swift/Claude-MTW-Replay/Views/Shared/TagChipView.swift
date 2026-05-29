import SwiftUI
struct TagChipView: View {
    @Environment(AppState.self) private var appState
    let tag: String; var onRemove: (() -> Void)? = nil
    var body: some View {
        HStack(spacing: DesignTokens.space4) {
            Text(tag).font(.caption2)
            if let onRemove { Button { onRemove() } label: { Image(systemName: "xmark").font(.caption2) } .buttonStyle(.plain) }
        }.padding(.horizontal, DesignTokens.space6).padding(.vertical, DesignTokens.space2).background(appState.theme.accent.opacity(0.2), in: Capsule())
    }
}
