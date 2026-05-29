import SwiftUI
struct TranscriptView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = TranscriptViewModel()
    var body: some View {
        VStack(spacing: 0) {
            TranscriptSearchBar(searchText: $vm.searchText, matchCount: vm.matchCount, onNext: vm.nextMatch, onPrev: vm.prevMatch)
            TranscriptFilterBar(showUser: $vm.showUser, showAssistant: $vm.showAssistant, showTools: $vm.showTools, showThinking: $vm.showThinking)
            ScrollView { LazyVStack(spacing: DesignTokens.space12) {
                ForEach(vm.filteredTurns, id: \.index) { turn in TranscriptTurnView(turn: turn) }
            }.padding() }
        }
        .onChange(of: vm.searchText) { vm.updateMatchCount() }
        .onChange(of: vm.showUser) { vm.updateMatchCount() }
        .onChange(of: vm.showAssistant) { vm.updateMatchCount() }
        .onChange(of: vm.showTools) { vm.updateMatchCount() }
        .onChange(of: vm.showThinking) { vm.updateMatchCount() }
        .task(id: appState.selectedSessionPath) {
            if let p = appState.selectedSessionPath { await vm.loadSession(path: URL(fileURLWithPath: p)) }
        }
    }
}
