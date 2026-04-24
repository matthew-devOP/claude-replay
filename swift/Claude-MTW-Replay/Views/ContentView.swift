import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        NavigationSplitView {
            SidebarView()
        } detail: {
            Group {
                switch appState.currentTab {
                case .dashboard: DashboardView()
                case .replay: ReplayView()
                case .transcript: TranscriptView()
                case .editor: EditorView()
                case .stats: StatsView()
                case .git: GitView()
                }
            }
        }
        .sheet(isPresented: $state.showExportSheet) { ExportSheet() }
        .sheet(isPresented: $state.showSearchSheet) { GlobalSearchView() }
        .sheet(isPresented: $state.showKeyboardShortcuts) { KeyboardShortcutsView() }
    }
}
