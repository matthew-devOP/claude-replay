import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// Editable list of bookmarks for the currently-loaded session.
/// Reachable from `ReplayView`'s "Edit Bookmarks" button. Supports
/// add / rename / delete and JSON import/export (CLI-compatible:
/// `[{"turn": 5, "label": "First failure"}, ...]`).
struct BookmarksEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Bindable var vm: ReplayViewModel

    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if vm.bookmarks.isEmpty {
                emptyState
            } else {
                list
            }
            Divider()
            footer
        }
        .frame(minWidth: 480, minHeight: 360)
        .alert(
            "Bookmarks Error",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ),
            actions: { Button("OK") { errorMessage = nil } },
            message: { Text(errorMessage ?? "") }
        )
    }

    private var header: some View {
        HStack {
            Text("Bookmarks")
                .font(.headline)
            Spacer()
            Button {
                vm.addBookmark(
                    turnIndex: vm.currentTurnIndex,
                    label: "Bookmark \(vm.bookmarks.count + 1)"
                )
            } label: {
                Label("Add", systemImage: "plus")
            }
            .help("Add bookmark at current turn (\(vm.currentTurnIndex))")
        }
        .padding(12)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("No bookmarks yet")
                .foregroundStyle(.secondary)
            Text("Press B during replay or click Add to create one.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var list: some View {
        List {
            ForEach(vm.bookmarks) { bm in
                BookmarkRow(
                    bookmark: bm,
                    onRename: { newLabel in vm.updateBookmark(id: bm.id, label: newLabel) },
                    onDelete: { vm.removeBookmark(id: bm.id) },
                    onJump: {
                        vm.seekToTurn(bm.turn)
                        dismiss()
                    }
                )
            }
        }
        .listStyle(.inset)
    }

    private var footer: some View {
        HStack {
            Button("Import JSON…", action: importJSON)
            Button("Export JSON…", action: exportJSON)
                .disabled(vm.bookmarks.isEmpty)
            Spacer()
            Button("Done") { dismiss() }
                .keyboardShortcut(.return, modifiers: [.command])
                .buttonStyle(.borderedProminent)
        }
        .padding(12)
    }

    // MARK: - Import / Export

    private func importJSON() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            try vm.loadBookmarksJSON(data)
        } catch {
            errorMessage = "Could not import bookmarks: \(error.localizedDescription)"
        }
    }

    private func exportJSON() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "bookmarks.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try vm.bookmarksJSON()
            try data.write(to: url)
        } catch {
            errorMessage = "Could not export bookmarks: \(error.localizedDescription)"
        }
    }
}

private struct BookmarkRow: View {
    let bookmark: Bookmark
    let onRename: (String) -> Void
    let onDelete: () -> Void
    let onJump: () -> Void

    @State private var label: String

    init(
        bookmark: Bookmark,
        onRename: @escaping (String) -> Void,
        onDelete: @escaping () -> Void,
        onJump: @escaping () -> Void
    ) {
        self.bookmark = bookmark
        self.onRename = onRename
        self.onDelete = onDelete
        self.onJump = onJump
        self._label = State(initialValue: bookmark.label)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onJump) {
                Text("Turn \(bookmark.turn)")
                    .font(.caption)
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
            }
            .buttonStyle(.plain)
            .help("Jump to turn \(bookmark.turn)")

            TextField("Label", text: $label, onCommit: commitRename)
                .textFieldStyle(.roundedBorder)
                .onSubmit(commitRename)
                .onChange(of: label) { _, _ in
                    // Live-debounce by committing only on submit/lose focus;
                    // SwiftUI TextField gives us the latter via onCommit on macOS.
                }

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete bookmark")
        }
        .padding(.vertical, 2)
    }

    private func commitRename() {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != bookmark.label else { return }
        onRename(trimmed)
    }
}
