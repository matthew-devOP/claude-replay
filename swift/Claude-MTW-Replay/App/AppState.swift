import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard, chats, replay, transcript, editor, stats, git
    var id: String { rawValue }
    var label: String {
        switch self {
        case .chats: return "Chats"
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
        }
    }
}

@Observable
final class AppState {
    var currentTab: AppTab = .dashboard
    var selectedProjectDirName: String?
    var selectedProjectSource: String = "claude"
    var selectedProject: ProjectEntry?
    var selectedSessionPath: String?
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
        currentTab = .replay
    }

    func switchTab(_ tab: AppTab) {
        currentTab = tab
    }

    func setClaudeAccount(_ dirName: String) {
        guard AccountStore.availableAccounts().contains(where: { $0.dirName == dirName }) else { return }
        claudeAccountDir = dirName
        AccountStore.save(dirName)
        selectedProjectDirName = nil
        selectedProject = nil
        selectedSessionPath = nil
    }
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
