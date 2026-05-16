import AppKit
import Foundation

/// Persisted recent session entry written to / read from `UserDefaults`.
struct RecentSessionEntry: Codable, Equatable {
    let path: String
    let displayName: String
}

extension Notification.Name {
    /// Posted by the menu bar (or anywhere else) when the user picks a session
    /// outside of the normal in-app navigation. Object userInfo carries `"path"`.
    static let menuBarDidSelectSession = Notification.Name("menuBarDidSelectSession")
    /// Posted by the menu bar when the user picks a project folder via `NSOpenPanel`.
    static let menuBarDidSelectProjectFolder = Notification.Name("menuBarDidSelectProjectFolder")
    /// Posted whenever a session is selected somewhere in the app, so the
    /// status item controller can persist it to the "recent sessions" list.
    /// userInfo: `["path": String, "displayName": String?]`.
    static let sessionSelected = Notification.Name("sessionSelected")
}

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {

    // MARK: - Storage

    private static let recentSessionsKey = "recentSessions"
    private static let maxRecentSessions = 10

    /// Append a session to the persisted "recent sessions" list (deduplicated,
    /// most-recent-first, capped at `maxRecentSessions`).
    static func addRecentSession(path: String, displayName: String? = nil) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let name = displayName ?? defaultDisplayName(for: trimmed)
        var current = loadRecentSessions()
        current.removeAll { $0.path == trimmed }
        current.insert(RecentSessionEntry(path: trimmed, displayName: name), at: 0)
        if current.count > maxRecentSessions {
            current = Array(current.prefix(maxRecentSessions))
        }
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: recentSessionsKey)
        }
    }

    static func loadRecentSessions() -> [RecentSessionEntry] {
        guard let data = UserDefaults.standard.data(forKey: recentSessionsKey) else { return [] }
        if let decoded = try? JSONDecoder().decode([RecentSessionEntry].self, from: data) {
            return decoded
        }
        return []
    }

    private static func defaultDisplayName(for path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let base = url.deletingPathExtension().lastPathComponent
        return base.isEmpty ? path : base
    }

    // MARK: - State

    private var statusItem: NSStatusItem?
    private var sessionSelectedObserver: NSObjectProtocol?

    // MARK: - Install / Uninstall

    func install() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "play.rectangle", accessibilityDescription: "Claude MTW Replay")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Claude MTW Replay"
        }
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
        rebuildMenu()

        // Listen for session-selected notifications anywhere in the app so we
        // can keep the "Recent Sessions" submenu fresh without touching
        // AppState directly.
        sessionSelectedObserver = NotificationCenter.default.addObserver(
            forName: .sessionSelected,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let info = note.userInfo ?? [:]
            let path = (info["path"] as? String) ?? ""
            let display = info["displayName"] as? String
            guard !path.isEmpty else { return }
            Task { @MainActor in
                StatusItemController.addRecentSession(path: path, displayName: display)
                self?.rebuildMenu()
            }
        }
    }

    func uninstall() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
        if let observer = sessionSelectedObserver {
            NotificationCenter.default.removeObserver(observer)
            sessionSelectedObserver = nil
        }
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    // MARK: - Menu construction

    private func rebuildMenu() {
        guard let menu = statusItem?.menu else { return }
        menu.removeAllItems()

        let open = NSMenuItem(title: "Open Main Window",
                              action: #selector(openMainWindow),
                              keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        menu.addItem(.separator())

        // Recent Sessions submenu
        let recentItem = NSMenuItem(title: "Recent Sessions", action: nil, keyEquivalent: "")
        let recentMenu = NSMenu(title: "Recent Sessions")
        let recents = Array(Self.loadRecentSessions().prefix(5))
        if recents.isEmpty {
            let empty = NSMenuItem(title: "No recent sessions", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            recentMenu.addItem(empty)
        } else {
            for entry in recents {
                let mi = NSMenuItem(title: entry.displayName,
                                    action: #selector(openRecentSession(_:)),
                                    keyEquivalent: "")
                mi.target = self
                mi.representedObject = entry.path
                mi.toolTip = entry.path
                recentMenu.addItem(mi)
            }
        }
        recentItem.submenu = recentMenu
        menu.addItem(recentItem)

        menu.addItem(.separator())

        let openFolder = NSMenuItem(title: "Open Project Folder…",
                                    action: #selector(openProjectFolder),
                                    keyEquivalent: "")
        openFolder.target = self
        menu.addItem(openFolder)

        let prefs = NSMenuItem(title: "Preferences…",
                               action: #selector(openPreferences),
                               keyEquivalent: ",")
        prefs.keyEquivalentModifierMask = [.command]
        prefs.target = self
        menu.addItem(prefs)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Claude MTW Replay",
                              action: #selector(quitApp),
                              keyEquivalent: "q")
        quit.keyEquivalentModifierMask = [.command]
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: - Actions

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        // Show & order-front any existing app windows; if none are visible,
        // ask AppKit to (re)open the default window for the app.
        var didShow = false
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
            didShow = true
        }
        if !didShow {
            NSApp.sendAction(#selector(NSApplication.unhideWithoutActivation), to: nil, from: nil)
        }
    }

    @objc private func openRecentSession(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        openMainWindow()
        NotificationCenter.default.post(
            name: .menuBarDidSelectSession,
            object: nil,
            userInfo: ["path": path]
        )
    }

    @objc private func openProjectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.title = "Open Project Folder"
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                self?.openMainWindow()
                NotificationCenter.default.post(
                    name: .menuBarDidSelectProjectFolder,
                    object: nil,
                    userInfo: ["url": url, "path": url.path]
                )
            }
        }
    }

    @objc private func openPreferences() {
        NSApp.activate(ignoringOtherApps: true)
        // Try the modern SwiftUI Settings selector first; fall back to the
        // legacy AppKit one for older macOS versions.
        if NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) { return }
        _ = NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
