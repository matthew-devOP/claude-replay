import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard, replay, transcript, editor, stats, git
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
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
    var selectedSessionPath: String?
    var selectedThemeName: String = "tokyo-night"
    var showExportSheet = false
    var showSearchSheet = false
    var showKeyboardShortcuts = false
    var searchQuery = ""
    var sidebarSelection: String?
    var errorMessage: String?

    func selectProject(_ dirName: String) {
        selectedProjectDirName = dirName
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
}
