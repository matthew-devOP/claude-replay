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

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.filteredSessions) { session in
                        SessionRowView(
                            session: session,
                            isCompareSelected: vm.compareSelection.contains(session.path),
                            compareMode: vm.compareMode,
                            onTapCompare: { vm.toggleCompareSelection(session.path) },
                            onAction: handle(_:for:)
                        )
                        .onAppear { vm.enrichIfNeeded(session) }
                        Divider()
                    }
                }
            }
            if vm.compareMode {
                compareBar
            }
        }
    }

    // MARK: - Header (sortable column titles)

    private var headerRow: some View {
        HStack(spacing: 0) {
            cell("SESSION", width: 130)
            cell("PREVIEW", width: nil, alignment: .leading)
            sortable("DATE", key: .date, width: 110)
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
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(appState.theme.textDim)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(appState.theme.bgSurface.opacity(0.5))
    }

    @ViewBuilder
    private func cell(_ title: String, width: CGFloat?, alignment: Alignment = .leading) -> some View {
        Text(title)
            .frame(width: width, alignment: alignment)
            .padding(.trailing, 8)
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
            HStack(spacing: 2) {
                if align == .trailing { Spacer() }
                Text(title)
                if vm.sortKey == key {
                    Image(systemName: vm.sortAscending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: 7))
                }
                if align == .leading { Spacer() }
            }
            .frame(width: width)
            .padding(.trailing, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(vm.sortKey == key ? appState.theme.accent : appState.theme.textDim)
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
        .padding(12)
        .background(appState.theme.bgSurface)
        .overlay(alignment: .top) {
            Rectangle().fill(appState.theme.border).frame(height: 0.5)
        }
    }

    // MARK: - Action dispatch

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
