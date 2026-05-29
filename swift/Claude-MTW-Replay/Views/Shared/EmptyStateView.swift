import SwiftUI
struct EmptyStateView: View {
    let icon: String; let title: String; var subtitle: String = ""; var iconSize: CGFloat = 48
    var body: some View {
        VStack(spacing: DesignTokens.space12) {
            Image(systemName: icon).font(.system(size: iconSize)).foregroundStyle(.secondary)
            Text(title).font(.title2).foregroundStyle(.secondary)
            if !subtitle.isEmpty { Text(subtitle).font(.caption).foregroundStyle(.tertiary) }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
