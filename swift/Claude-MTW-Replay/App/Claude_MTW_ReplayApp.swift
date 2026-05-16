import SwiftUI
import AppKit
import UniformTypeIdentifiers

@main
struct Claude_MTW_ReplayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()
    @State private var showKeyboardShortcuts = false
    @State private var importErrorMessage: String?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .frame(minWidth: 900, minHeight: 600)
                .task { appState.favoritesVM.loadFavorites() }
                .sheet(isPresented: $showKeyboardShortcuts) { KeyboardShortcutsView() }
                .onKeyPress("?") { showKeyboardShortcuts = true; return .handled }
                // Menu-bar status item -> session selection bridge.
                .onReceive(NotificationCenter.default.publisher(for: .menuBarDidSelectSession)) { note in
                    guard let path = note.userInfo?["path"] as? String else { return }
                    appState.selectSession(path)
                }
                // Persist recent sessions whenever a session is selected anywhere in the app.
                .onChange(of: appState.selectedSessionPath) { _, newValue in
                    guard let path = newValue, !path.isEmpty else { return }
                    NotificationCenter.default.post(
                        name: .sessionSelected,
                        object: nil,
                        userInfo: ["path": path]
                    )
                }
                .alert(
                    "Import Failed",
                    isPresented: Binding(
                        get: { importErrorMessage != nil },
                        set: { if !$0 { importErrorMessage = nil } }
                    ),
                    actions: { Button("OK") { importErrorMessage = nil } },
                    message: { Text(importErrorMessage ?? "") }
                )
        }
        .defaultSize(width: 1200, height: 800)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .newItem) {
                Button("Import HTML Replay…") { importHTMLReplay() }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
            }
            CommandMenu("Navigate") {
                ForEach(AppTab.allCases) { tab in
                    Button(tab.label) { appState.switchTab(tab) }
                        .keyboardShortcut(KeyEquivalent(Character("\(AppTab.allCases.firstIndex(of: tab)! + 1)")), modifiers: .command)
                }
                Divider()
                Button("Search...") { appState.showSearchSheet = true }
                    .keyboardShortcut("f", modifiers: .command)
                Button("Export...") { appState.showExportSheet = true }
                    .keyboardShortcut("e", modifiers: .command)
            }
            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts") { showKeyboardShortcuts = true }
                    .keyboardShortcut("/", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
        }
    }

    /// Open an `NSOpenPanel` filtered to `.html`, decode via `HTMLExtractor`,
    /// then push the result into `appState` as an ephemeral `ImportedSession`.
    /// Nothing is written to disk — the import lives only in memory.
    private func importHTMLReplay() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.html]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Import HTML Replay"
        panel.prompt = "Import"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let html = try String(contentsOf: url, encoding: .utf8)
            let extracted = try HTMLExtractor.extractData(html: html)
            let session = ImportedSession(
                turns: extracted.turns,
                bookmarks: extracted.bookmarks,
                displayName: url.deletingPathExtension().lastPathComponent,
                source: url.path
            )
            appState.selectImportedSession(session)
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }
}
