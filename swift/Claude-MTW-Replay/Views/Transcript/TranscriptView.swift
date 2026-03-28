import SwiftUI
struct TranscriptView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = TranscriptViewModel()
    var body: some View {
        VStack(spacing: 0) {
            TranscriptSearchBar(searchText: $vm.searchText, matchCount: vm.matchCount, onNext: vm.nextMatch, onPrev: vm.prevMatch)
            TranscriptFilterBar(showUser: $vm.showUser, showAssistant: $vm.showAssistant, showTools: $vm.showTools, showThinking: $vm.showThinking)
            ScrollView { LazyVStack(spacing: 12) {
                ForEach(vm.filteredTurns, id: \.index) { turn in TranscriptTurnView(turn: turn) }
            }.padding() }
        }
        .task(id: appState.selectedSessionPath) {
            if let p = appState.selectedSessionPath { await vm.loadSession(path: URL(fileURLWithPath: p)) }
        }
    }
}
