import SwiftUI
import AppKit
import UniformTypeIdentifiers

@main
struct Claude_MTW_ReplayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()
    @State private var showKeyboardShortcuts = false
    @State private var importErrorMessage: String?
    @State private var isDropTargeted = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .frame(minWidth: 900, minHeight: 600)
                .task { appState.favoritesVM.loadFavorites() }
                .sheet(isPresented: $showKeyboardShortcuts) { KeyboardShortcutsView() }
                .onKeyPress("?") { showKeyboardShortcuts = true; return .handled }
                // P3.1 — accept dragged .jsonl session files anywhere in the window.
                .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                    for provider in providers {
                        _ = provider.loadObject(ofClass: URL.self) { url, _ in
                            guard let url, url.pathExtension == "jsonl" else { return }
                            Task { @MainActor in
                                NotificationCenter.default.post(
                                    name: .menuBarDidSelectSession,
                                    object: nil,
                                    userInfo: ["path": url.path]
                                )
                                RecentSessionsStore.shared.add(path: url.path)
                            }
                        }
                    }
                    return true
                }
                .overlay {
                    if isDropTargeted {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.accentColor, lineWidth: 3)
                            .background(Color.accentColor.opacity(0.08))
                            .padding(8)
                            .allowsHitTesting(false)
                    }
                }
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
            // P3.2 — Open Recent submenu sourced from `RecentSessionsStore`.
            CommandGroup(after: .newItem) {
                Menu("Open Recent") {
                    let recents = RecentSessionsStore.shared.recents()
                    if recents.isEmpty {
                        Text("No recent sessions")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(recents, id: \.path) { entry in
                            Button(entry.displayName) {
                                NotificationCenter.default.post(
                                    name: .menuBarDidSelectSession,
                                    object: nil,
                                    userInfo: ["path": entry.path]
                                )
                            }
                        }
                    }
                    Divider()
                    Button("Clear Menu") {
                        RecentSessionsStore.shared.clear()
                    }
                }
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
