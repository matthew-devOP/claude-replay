import SwiftUI

@main
struct Claude_MTW_ReplayApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 1200, height: 800)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Navigate") {
                ForEach(AppTab.allCases) { tab in
                    Button(tab.label) { appState.switchTab(tab) }
                        .keyboardShortcut(KeyEquivalent(Character("\(AppTab.allCases.firstIndex(of: tab)! + 1)")), modifiers: .command)
                }
                Divider()
                Button("Search...") { appState.showSearchSheet = true }
                    .keyboardShortcut("f", modifiers: .command)
                Button("Export...") { appState.showExportSheet = true }
                    .keyboardShortcut("e", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}
