import SwiftUI

/// Sessions table for the Dashboard. Mirrors the web layout:
/// SESSION (with star + add-tag chip) · PREVIEW · DATE · DURATION ·
/// TURNS · SIZE · ACTIONS (Replay / Transcript / Edit / MD) · COMPARE.
///
/// Per-row enrichment (preview text, turn count, duration) is computed
/// on-demand from `SessionMetaService` the first time a row appears in
/// the LazyVStack viewport — keeps initial load fast for projects with
/// many sessions while still showing rich detail as the user scrolls.
struct SessionTableView: View {
    @Environment(AppState.self) private var appState
    @Bindable var vm: SessionListViewModel

    /// Optional callback fired when the user wants to open the Compare
    /// diff overlay. ChatsView/DashboardView wires this to a sheet.
    var onCompare: (() -> Void)? = nil

    // P1.2 — Session chaining: ephemeral chained-replay sheet state.
    @State private var chainedTurns: [Turn]? = nil
    @State private var chainedSessionCount: Int = 0
    @State private var isChaining: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            chainToolbar
            headerRow
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.filteredSessions) { session in
                        rowContainer(for: session)
                        Divider()
                    }
                }
            }
            if vm.compareMode {
                compareBar
            }
            if vm.chainMode {
                chainBar
            }
        }
        .focusable()
        .onKeyPress(.upArrow) {
            moveTableSelection(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveTableSelection(by: 1)
            return .handled
        }
        .onKeyPress(.return) {
            if appState.selectedSessionPath != nil {
                appState.switchTab(.replay)
                return .handled
            }
            return .ignored
        }
        .sheet(isPresented: chainSheetBinding) {
            ChainedReplaySheet(
                turns: chainedTurns ?? [],
                sessionCount: chainedSessionCount
            )
        }
        .alert("Chaining failed", isPresented: chainErrorBinding) {
            Button("OK", role: .cancel) { vm.chainErrorMessage = nil }
        } message: {
            Text(vm.chainErrorMessage ?? "")
        }
    }

    // MARK: - Row container (adds chain checkbox when chainMode is on)

    @ViewBuilder
    private func rowContainer(for session: SessionEntry) -> some View {
        HStack(spacing: 0) {
            if vm.chainMode {
                Button {
                    vm.toggleSelection(path: session.path)
                } label: {
                    Image(systemName: vm.selectedPaths.contains(session.path)
                          ? "checkmark.square.fill"
                          : "square")
                        .foregroundStyle(vm.selectedPaths.contains(session.path)
                                         ? appState.theme.accent
                                         : appState.theme.textDim)
                        .frame(width: 32, alignment: .center)
                }
                .buttonStyle(.plain)
                .help("Include this session in the chain")
                .accessibilityLabel(vm.selectedPaths.contains(session.path)
                                    ? "Deselect session from chain"
                                    : "Select session for chain")
            }
            SessionRowView(
                session: session,
                isCompareSelected: vm.compareSelection.contains(session.path),
                compareMode: vm.compareMode,
                onTapCompare: { vm.toggleCompareSelection(session.path) },
                onAction: handle(_:for:)
            )
            .onAppear { vm.enrichIfNeeded(session) }
        }
    }

    // MARK: - Chain toolbar (P1.2)

    private var chainToolbar: some View {
        HStack(spacing: DesignTokens.space8) {
            Button {
                vm.chainMode.toggle()
                if !vm.chainMode { vm.selectedPaths.removeAll() }
            } label: {
                Label(vm.chainMode ? "Cancel Chain" : "Chain Sessions",
                      systemImage: "link")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)
            .help("Multi-select sessions and replay them as one chronological stream")

            if vm.chainMode {
                Button {
                    Task { await runChain() }
                } label: {
                    if isChaining {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Chain (\(vm.selectedPaths.count))",
                              systemImage: "play.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.selectedPaths.count < 2 || isChaining)
            }
            Spacer()
        }
        .padding(.horizontal, DesignTokens.space16)
        .padding(.vertical, DesignTokens.space6)
    }

    private func runChain() async {
        isChaining = true
        defer { isChaining = false }
        guard let chained = await vm.chainSelected(), !chained.isEmpty else { return }
        chainedSessionCount = vm.selectedPaths.count
        chainedTurns = chained
    }

    private var chainSheetBinding: Binding<Bool> {
        Binding(
            get: { chainedTurns != nil },
            set: { presented in if !presented { chainedTurns = nil } }
        )
    }

    private var chainErrorBinding: Binding<Bool> {
        Binding(
            get: { vm.chainErrorMessage != nil },
            set: { presented in if !presented { vm.chainErrorMessage = nil } }
        )
    }

    // MARK: - Header (sortable column titles)

    private var headerRow: some View {
        HStack(spacing: 0) {
            cell("SESSION", width: 130)
            if appState.isAllAccounts { cell("ACCOUNT", width: 90) }
            cell("PREVIEW", width: nil, alignment: .leading)
            sortable("CREATED", key: .created, width: 110)
            sortable("LAST ACTIVE", key: .date, width: 110)
            sortable("DURATION", key: .duration, width: 110)
            sortable("TURNS", key: .turns, width: 80, align: .trailing)
            sortable("SIZE", key: .size, width: 90, align: .trailing)
            cell("ACTIONS", width: 280, alignment: .leading)
            Button {
                vm.compareMode.toggle()
                if !vm.compareMode { vm.compareSelection.removeAll() }
            } label: {
                Image(systemName: vm.compareMode ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
            }
            .buttonStyle(.plain)
            .foregroundStyle(vm.compareMode ? appState.theme.accent : appState.theme.textDim)
            .frame(width: 70)
            .help("Compare two sessions side-by-side")
            .accessibilityLabel(vm.compareMode ? "Exit compare mode" : "Enter compare mode")
            .accessibilityHint("Compare two sessions side-by-side")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(appState.theme.textDim)
        .padding(.horizontal, DesignTokens.space16)
        .padding(.vertical, DesignTokens.space8)
        .background(appState.theme.bgSurface.opacity(0.5))
    }

    @ViewBuilder
    private func cell(_ title: String, width: CGFloat?, alignment: Alignment = .leading) -> some View {
        Text(title)
            .frame(width: width, alignment: alignment)
            .padding(.trailing, DesignTokens.space8)
    }

    private func sortable(_ title: String, key: SessionSortKey, width: CGFloat, align: HorizontalAlignment = .leading) -> some View {
        Button {
            if vm.sortKey == key {
                vm.sortAscending.toggle()
            } else {
                vm.sortKey = key
                vm.sortAscending = false
            }
        } label: {
            HStack(spacing: DesignTokens.space2) {
                if align == .trailing { Spacer() }
                Text(title)
                if vm.sortKey == key {
                    Image(systemName: vm.sortAscending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: 7))
                }
                if align == .leading { Spacer() }
            }
            .frame(width: width)
            .padding(.trailing, DesignTokens.space8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(vm.sortKey == key ? appState.theme.accent : appState.theme.textDim)
    }

    // MARK: - Chain bar

    private var chainBar: some View {
        HStack {
            Text("\(vm.selectedPaths.count) selected for chain")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Clear") {
                vm.selectedPaths.removeAll()
            }
            .disabled(vm.selectedPaths.isEmpty)
        }
        .padding(DesignTokens.space12)
        .background(appState.theme.bgSurface)
        .overlay(alignment: .top) {
            Rectangle().fill(appState.theme.border).frame(height: 0.5)
        }
    }

    // MARK: - Compare bar

    private var compareBar: some View {
        HStack {
            Text("\(vm.compareSelection.count) of 2 selected for compare")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Cancel") {
                vm.compareMode = false
                vm.compareSelection.removeAll()
            }
            Button("Compare") { onCompare?() }
                .buttonStyle(.borderedProminent)
                .disabled(vm.compareSelection.count != 2)
                .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(DesignTokens.space12)
        .background(appState.theme.bgSurface)
        .overlay(alignment: .top) {
            Rectangle().fill(appState.theme.border).frame(height: 0.5)
        }
    }

    // MARK: - Action dispatch

    // P3.5 — Keyboard navigation through the sessions list.
    private func moveTableSelection(by delta: Int) {
        let rows = vm.filteredSessions
        guard !rows.isEmpty else { return }
        let currentIndex: Int
        if let cur = appState.selectedSessionPath,
           let idx = rows.firstIndex(where: { $0.path == cur }) {
            currentIndex = idx
        } else {
            currentIndex = delta > 0 ? -1 : rows.count
        }
        let next = max(0, min(rows.count - 1, currentIndex + delta))
        appState.selectedSessionPath = rows[next].path
    }

    private func handle(_ action: SessionRowAction, for session: SessionEntry) {
        appState.selectedSessionPath = session.path
        switch action {
        case .replay:     appState.switchTab(.replay)
        case .transcript: appState.switchTab(.transcript)
        case .edit:       appState.switchTab(.editor)
        case .markdown:   appState.showExportSheet = true
        }
    }
}
