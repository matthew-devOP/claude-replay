import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        NavigationSplitView {
            SidebarView()
        } detail: {
            VStack(spacing: 0) {
                // Visible tab strip — mirrors the web header nav so users
                // can discover Replay/Transcript/Editor/Stats/Git/Chats
                // without learning Cmd+1..7.
                MainTabBarView()
                Group {
                    switch appState.currentTab {
                    case .dashboard: DashboardView()
                    case .chats: ChatsView()
                    case .replay: ReplayView()
                    case .transcript: TranscriptView()
                    case .editor: EditorView()
                    case .stats: StatsView()
                    case .git: GitView()
                    }
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
}
