import SwiftUI
struct ReplayView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = ReplayViewModel()
    var body: some View {
        VStack(spacing: 0) {
            if vm.turns.isEmpty && !vm.isLoading {
                EmptyStateView(icon: "play.circle", title: "No Session Loaded", subtitle: "Select a session to replay")
            } else {
                ScrollViewReader { proxy in
                    ScrollView { LazyVStack(spacing: 16) {
                        ForEach(Array(vm.turns.enumerated()), id: \.offset) { index, turn in
                            ReplayTurnView(turn: turn, turnNumber: index + 1,
                                revealedBlocks: index + 1 <= vm.currentTurnIndex ? (index + 1 == vm.currentTurnIndex ? vm.revealedBlockCount : turn.blocks.count) : 0,
                                showThinking: vm.showThinking, showToolCalls: vm.showToolCalls)
                            .id(index)
                            .opacity(index + 1 <= vm.currentTurnIndex ? 1.0 : 0.25)
                            .animation(.easeInOut(duration: 0.4), value: vm.currentTurnIndex)
                        }
                    }.padding() }
                    .onChange(of: vm.currentTurnIndex) { _, idx in
                        withAnimation { proxy.scrollTo(max(0, idx - 1), anchor: .center) }
                    }
                }
                ReplayControlsView(vm: vm)
            }
        }
        .task(id: appState.selectedSessionPath) {
            if let p = appState.selectedSessionPath { await vm.loadSession(path: URL(fileURLWithPath: p)) }
        }
    }
}
