import SwiftUI
struct ReplayView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = ReplayViewModel()
    @State private var showBookmarksEditor = false
    @State private var showBookmarkPrompt = false
    @State private var pendingBookmarkLabel = ""
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
            .onKeyPress("b") {
                pendingBookmarkLabel = "Bookmark \(vm.bookmarks.count + 1)"
                showBookmarkPrompt = true
                return .handled
            }
            .onKeyPress(.escape) { vm.pause(); return .handled }
            .task(id: appState.selectedSessionPath) {
                if let p = appState.selectedSessionPath {
                    await vm.loadSession(path: URL(fileURLWithPath: p))
                }
            }
            .onChange(of: appState.importedSession?.id) { _, _ in
                if let imp = appState.importedSession {
                    vm.loadImportedSession(imp)
                }
            }
            .onAppear {
                if let imp = appState.importedSession, vm.turns.isEmpty {
                    vm.loadImportedSession(imp)
                }
            }
            .sheet(isPresented: $showBookmarksEditor) {
                BookmarksEditorView(vm: vm)
                    .environment(appState)
            }
            .sheet(isPresented: $showBookmarkPrompt) {
                BookmarkPromptSheet(
                    label: $pendingBookmarkLabel,
                    turnIndex: vm.currentTurnIndex,
                    onCancel: { showBookmarkPrompt = false },
                    onSave: {
                        let label = pendingBookmarkLabel.trimmingCharacters(in: .whitespaces)
                        vm.addBookmark(
                            turnIndex: vm.currentTurnIndex,
                            label: label.isEmpty ? "Bookmark \(vm.bookmarks.count + 1)" : label
                        )
                        showBookmarkPrompt = false
                    }
                )
            }
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            if vm.turns.isEmpty && !vm.isLoading {
                EmptyStateView(icon: "play.circle", title: "No Session Loaded", subtitle: "Select a session to replay")
            } else {
                bookmarksToolbar
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
    private var bookmarksToolbar: some View {
        HStack(spacing: DesignTokens.space8) {
            if let imp = appState.importedSession {
                Label(imp.displayName, systemImage: "doc.richtext")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                if let path = appState.selectedSessionPath {
                    appState.resumeChatLive(path: path)
                }
            } label: {
                Label("Continue (live)", systemImage: "play.circle.fill")
            }
            .help("Resume this session live in the Chats tab")
            .disabled(appState.selectedSessionPath == nil)
            Button {
                pendingBookmarkLabel = "Bookmark \(vm.bookmarks.count + 1)"
                showBookmarkPrompt = true
            } label: {
                Label("Add Bookmark", systemImage: "bookmark")
            }
            .help("Add a bookmark at the current turn (B)")
            .keyboardShortcut("b", modifiers: [])
            Button {
                showBookmarksEditor = true
            } label: {
                Label("Edit Bookmarks", systemImage: "bookmark.square")
            }
            .help("Open bookmarks editor")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal)
        .padding(.top, DesignTokens.space6)
    }

    @ViewBuilder
    private var turnList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DesignTokens.space16) {
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
            .accessibilityLabel("Replay turns")
            .accessibilityValue("Showing turn \(vm.currentTurnIndex) of \(vm.turns.count)")
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

// MARK: - Inline bookmark label prompt

private struct BookmarkPromptSheet: View {
    @Binding var label: String
    let turnIndex: Int
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.space12) {
            Text("Add Bookmark at Turn \(turnIndex)")
                .font(.headline)
            TextField("Label", text: $label)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onSave)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.escape, modifiers: [])
                Button("Add", action: onSave)
                    .keyboardShortcut(.return, modifiers: [])
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(DesignTokens.space20)
        .frame(minWidth: 320)
    }
}
