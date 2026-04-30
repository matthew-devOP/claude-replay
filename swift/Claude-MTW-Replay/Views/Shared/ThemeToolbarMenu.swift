import SwiftUI

/// Toolbar menu that surfaces the theme picker without forcing a trip
/// through Settings. Mirrors the web header's theme dropdown + the
/// "dark/light quick toggle" sun/moon button.
///
/// Two pieces:
///   - A standalone `ThemeQuickToggle` button — flips between
///     `claude-dark` and `claude-light` (the project defaults).
///   - The `ThemeToolbarMenu` itself — a Menu that lists every
///     built-in theme with the active one checkmarked.
struct ThemeToolbarMenu: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Menu {
            ForEach(ThemeName.allCases) { theme in
                Button {
                    setTheme(theme.rawValue)
                } label: {
                    if theme.rawValue == appState.selectedThemeName {
                        Label(theme.displayName, systemImage: "checkmark")
                    } else {
                        Text(theme.displayName)
                    }
                }
            }
        } label: {
            Label("Theme", systemImage: "paintpalette")
        }
        .help("Switch theme")
    }

    private func setTheme(_ name: String) {
        appState.selectedThemeName = name
        UserDefaults.standard.set(name, forKey: "defaultTheme")
    }
}

/// Single button that flips between Claude Light and Claude Dark — the
/// "sun/moon" quick toggle the web header provides next to the theme
/// dropdown. Uses the theme's own `isDark` flag so flipping works with
/// any dark/light theme pair, not just the Claude brand ones.
struct ThemeQuickToggle: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            toggle()
        } label: {
            Image(systemName: appState.theme.isDark ? "sun.max" : "moon")
        }
        .help("Toggle dark/light theme")
    }

    private func toggle() {
        let target = appState.theme.isDark ? "claude-light" : "claude-dark"
        appState.selectedThemeName = target
        UserDefaults.standard.set(target, forKey: "defaultTheme")
    }
}
