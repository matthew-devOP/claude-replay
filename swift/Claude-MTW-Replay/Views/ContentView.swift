import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        NavigationSplitView {
            SidebarView()
        } detail: {
            // Native TabView so the tab bar inherits Liquid Glass automatically
            // on macOS 26 (and standard chrome below it). Selection is bound to
            // `currentTab`, so the existing Cmd+1..8 commands keep working.
            TabView(selection: $state.currentTab) {
                ForEach(AppTab.allCases) { tab in
                    tabContent(for: tab)
                        .tabItem { Label(tab.label, systemImage: tab.icon) }
                        .tag(tab)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    SpinnerVerbView()
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    ThemeQuickToggle()
                    ThemeToolbarMenu()
                    Button {
                        state.showSearchSheet = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .help("Search all sessions (⌘F)")
                    .keyboardShortcut("f", modifiers: .command)
                    Button {
                        state.showKeyboardShortcuts = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .help("Keyboard shortcuts (?)")
                }
            }
        }
        .sheet(isPresented: $state.showExportSheet) { ExportSheet() }
        .sheet(isPresented: $state.showSearchSheet) { GlobalSearchView() }
        .sheet(isPresented: $state.showKeyboardShortcuts) { KeyboardShortcutsView() }
    }

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .dashboard: DashboardView()
        case .chats: ChatsView()
        case .replay: ReplayView()
        case .transcript: TranscriptView()
        case .editor: EditorView()
        case .stats: StatsView()
        case .git: GitView()
        case .docs: DocsView()
        }
    }
}
