import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard, chats, replay, transcript, editor, stats, git, docs
    var id: String { rawValue }
    var label: String {
        switch self {
        case .chats: return "Chats"
        case .docs: return "Docs"
        default: return rawValue.capitalized
        }
    }
    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .chats: return "bubble.left.and.exclamationmark.bubble.right"
        case .replay: return "play.circle"
        case .transcript: return "doc.text"
        case .editor: return "pencil.and.outline"
        case .stats: return "chart.bar"
        case .git: return "arrow.triangle.branch"
        case .docs: return "book.closed"
        }
    }
}

/// Ephemeral, in-memory pseudo-session populated by importing an HTML
/// replay (`File → Import HTML Replay…`). Not persisted anywhere.
struct ImportedSession: Identifiable, Hashable {
    let id: UUID
    let turns: [Turn]
    let bookmarks: [Bookmark]
    let displayName: String
    let source: String

    init(
        id: UUID = UUID(),
        turns: [Turn],
        bookmarks: [Bookmark],
        displayName: String,
        source: String
    ) {
        self.id = id
        self.turns = turns
        self.bookmarks = bookmarks
        self.displayName = displayName
        self.source = source
    }
}

@Observable
final class AppState {
    var currentTab: AppTab = .dashboard
    var selectedProjectDirName: String?
    var selectedProjectSource: String = "claude"
    var selectedProject: ProjectEntry?
    var selectedSessionPath: String?
    /// Path of a session that should be opened in the live Chats tab.
    /// Set by `resumeChatLive(path:)` from the Replay view's "Continue (live)"
    /// button; consumed and cleared by `ChatsView` after spawning a `ChatView`.
    var resumingChatPath: String? = nil
    /// Ephemeral imported HTML session; non-nil after `File → Import HTML…`.
    /// `ReplayView` observes this in addition to `selectedSessionPath`.
    var importedSession: ImportedSession?
    var selectedThemeName: String = "claude-dark"
    var claudeAccountDir: String = AccountStore.load()

    var theme: Theme {
        let themeName = ThemeName(rawValue: selectedThemeName) ?? .claudeDark
        return Theme.named(themeName)
    }
    var showExportSheet = false
    var showSearchSheet = false
    var showKeyboardShortcuts = false
    var sidebarSelection: String?
    var favoritesVM = FavoritesViewModel()

    func selectProject(_ dirName: String, source: String = "claude") {
        selectedProjectDirName = dirName
        selectedProjectSource = source
        selectedSessionPath = nil
        currentTab = .dashboard
    }

    func selectProject(_ project: ProjectEntry) {
        selectedProject = project
        selectedProjectDirName = project.dirName
        selectedProjectSource = project.source
        selectedSessionPath = nil
        currentTab = .dashboard
    }

    func selectSession(_ path: String) {
        selectedSessionPath = path
        importedSession = nil
        currentTab = .replay
    }

    /// Replace the current session with an ephemeral imported one
    /// (HTML replay). Clears `selectedSessionPath` so views don't try
    /// to load a disk file, and switches to the Replay tab.
    func selectImportedSession(_ session: ImportedSession) {
        importedSession = session
        selectedSessionPath = nil
        currentTab = .replay
    }

    func switchTab(_ tab: AppTab) {
        currentTab = tab
    }

    /// Hop from Replay into the live Chats tab, resuming the given session
    /// via the SDK. `ChatsView` watches `resumingChatPath` and opens a
    /// `ChatView` against that JSONL.
    func resumeChatLive(path: String) {
        resumingChatPath = path
        currentTab = .chats
    }

    func setClaudeAccount(_ dirName: String) {
        guard AccountStore.availableAccounts().contains(where: { $0.dirName == dirName }) else { return }
        claudeAccountDir = dirName
        AccountStore.save(dirName)
        selectedProjectDirName = nil
        selectedProject = nil
        selectedSessionPath = nil
    }

    /// Switch to the Docs tab and broadcast a request to focus a specific
    /// topic. `DocsView` observes `.docsDidRequestTopic` and updates its
    /// `selectedTopicId` accordingly.
    func showDoc(topicId: String) {
        currentTab = .docs
        NotificationCenter.default.post(name: .docsDidRequestTopic, object: topicId)
    }
}

extension Notification.Name {
    static let docsDidRequestTopic = Notification.Name("docsDidRequestTopic")
}

// MARK: - Multi-account (~/.claude, ~/.claude-work, ...)

struct ClaudeAccount: Identifiable, Hashable, Sendable {
    var id: String { dirName }
    let dirName: String
    var label: String {
        if dirName == ".claude" { return "main" }
        if dirName.hasPrefix(".claude-") || dirName.hasPrefix(".claude_") {
            return String(dirName.dropFirst(".claude-".count))
        }
        return dirName.hasPrefix(".") ? String(dirName.dropFirst()) : dirName
    }
    var path: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(dirName)
    }
}

enum AccountStore {
    private static let defaultsKey = "claudeAccountDir"
    static let defaultDirName = ".claude"

    static func load() -> String {
        UserDefaults.standard.string(forKey: defaultsKey) ?? defaultDirName
    }

    static func save(_ dirName: String) {
        UserDefaults.standard.set(dirName, forKey: defaultsKey)
    }

    /// Scan $HOME for ".claude" and ".claude-*" dirs that contain a "projects" subdir.
    static func availableAccounts() -> [ClaudeAccount] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var seen: Set<String> = [defaultDirName]
        var results: [ClaudeAccount] = [ClaudeAccount(dirName: defaultDirName)]
        let fm = FileManager.default
        if let entries = try? fm.contentsOfDirectory(atPath: home.path) {
            for name in entries where name != defaultDirName {
                guard name.range(of: #"^\.claude[-_].+$"#, options: .regularExpression) != nil else { continue }
                var isDir: ObjCBool = false
                let full = home.appendingPathComponent(name)
                guard fm.fileExists(atPath: full.path, isDirectory: &isDir), isDir.boolValue else { continue }
                let projects = full.appendingPathComponent("projects")
                guard fm.fileExists(atPath: projects.path) else { continue }
                if seen.insert(name).inserted {
                    results.append(ClaudeAccount(dirName: name))
                }
            }
        }
        return results.sorted { a, b in
            if a.dirName == defaultDirName { return true }
            if b.dirName == defaultDirName { return false }
            return a.dirName < b.dirName
        }
    }
}
