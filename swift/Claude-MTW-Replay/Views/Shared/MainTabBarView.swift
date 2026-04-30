import SwiftUI

/// Horizontal tab strip shown at the top of the detail pane in
/// `ContentView`. Mirrors the visible nav row from the web app
/// (`Projects | Editor | Docs` style) so users don't have to learn
/// `Cmd+1..7` to discover the other panes.
///
/// Themed via `AppState.theme.accent`; the active tab is highlighted
/// with the accent color and a subtle background tint.
struct MainTabBarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                tabButton(for: tab)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(appState.theme.bgSurface.opacity(0.6))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(appState.theme.border)
                .frame(height: 0.5)
        }
    }

    private func tabButton(for tab: AppTab) -> some View {
        let isActive = appState.currentTab == tab
        return Button {
            appState.switchTab(tab)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12, weight: .medium))
                Text(tab.label)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
            }
            .foregroundColor(isActive ? appState.theme.accent : appState.theme.textDim)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? appState.theme.accent.opacity(0.12) : .clear)
            )
        }
        .buttonStyle(.plain)
        .help("\(tab.label) (\(shortcutLabel(for: tab)))")
    }

    private func shortcutLabel(for tab: AppTab) -> String {
        guard let idx = AppTab.allCases.firstIndex(of: tab) else { return "" }
        return "⌘\(idx + 1)"
    }
}
