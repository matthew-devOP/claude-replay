import SwiftUI
struct ReplayView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = ReplayViewModel()
    @FocusState private var isFocused: Bool
    var body: some View {
        mainContent
            .focusable()
            .focused($isFocused)
            .onAppear { isFocused = true }
            .onKeyPress(.space) { vm.togglePlay(); return .handled }
            .onKeyPress("k") { vm.togglePlay(); return .handled }
            .onKeyPress(.rightArrow) { vm.stepForward(); return .handled }
            .onKeyPress(.leftArrow) { vm.stepBack(); return .handled }
            .onKeyPress("l") { vm.stepForward(); return .handled }
            .onKeyPress("h") { vm.stepBack(); return .handled }
            .onKeyPress("L") { vm.nextTurn(); return .handled }
            .onKeyPress("H") { vm.prevTurn(); return .handled }
            .onKeyPress(keys: [.rightArrow, .leftArrow], phases: .down) { press in
                if press.modifiers.contains(.shift) {
                    if press.key == .rightArrow { vm.nextTurn() } else { vm.prevTurn() }
                    return .handled
                }
                return .ignored
            }
            .onKeyPress("t") { vm.showThinking.toggle(); return .handled }
            .onKeyPress(.escape) { vm.pause(); return .handled }
            .task(id: appState.selectedSessionPath) {
                if let p = appState.selectedSessionPath {
                    await vm.loadSession(path: URL(fileURLWithPath: p))
                }
            }
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            if vm.turns.isEmpty && !vm.isLoading {
                EmptyStateView(icon: "play.circle", title: "No Session Loaded", subtitle: "Select a session to replay")
            } else {
                turnList
                if !vm.bookmarks.isEmpty {
                    BookmarkBarView(bookmarks: vm.bookmarks, totalTurns: vm.turns.count) { turn in
                        vm.seekToTurn(turn)
                    }.padding(.horizontal)
                }
                ReplayControlsView(vm: vm)
            }
        }
    }

    @ViewBuilder
    private var turnList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(Array(vm.turns.enumerated()), id: \.offset) { index, turn in
                        let revealed = revealedBlocks(for: index)
                        ReplayTurnView(
                            turn: turn,
                            turnNumber: index + 1,
                            revealedBlocks: revealed,
                            showThinking: vm.showThinking,
                            showToolCalls: vm.showToolCalls
                        )
                        .id(index)
                        .opacity(index + 1 <= vm.currentTurnIndex ? 1.0 : 0.25)
                        .animation(.easeInOut(duration: 0.4), value: vm.currentTurnIndex)
                    }
                }.padding()
            }
            .onChange(of: vm.currentTurnIndex) { _, idx in
                withAnimation { proxy.scrollTo(max(0, idx - 1), anchor: .center) }
            }
        }
    }

    private func revealedBlocks(for index: Int) -> Int {
        if index + 1 < vm.currentTurnIndex {
            return vm.turns[index].blocks.count
        } else if index + 1 == vm.currentTurnIndex {
            return vm.revealedBlockCount
        } else {
            return 0
        }
    }
}
