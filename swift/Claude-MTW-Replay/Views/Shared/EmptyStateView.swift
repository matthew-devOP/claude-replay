import SwiftUI
struct EmptyStateView: View {
    let icon: String; let title: String; var subtitle: String = ""
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 48)).foregroundStyle(.secondary)
            Text(title).font(.title2).foregroundStyle(.secondary)
            if !subtitle.isEmpty { Text(subtitle).font(.caption).foregroundStyle(.tertiary) }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
