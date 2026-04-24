import Foundation

@Observable
final class SessionListViewModel {
    var sessions: [SessionEntry] = []
    var isLoading = false
    var sortAscending = false
    var searchText = ""

    func loadSessions(projectDirName: String, source: String = "claude", claudeAccountDir: String = ".claude") async {
        isLoading = true
        defer { isLoading = false }
        if let details = SessionDiscovery.getProjectDetails(source: source, dirName: projectDirName, claudeAccountDir: claudeAccountDir) {
            sessions = details.sessions
        }
    }

    var filteredSessions: [SessionEntry] {
        let filtered = searchText.isEmpty ? sessions : sessions.filter {
            $0.sessionId.localizedCaseInsensitiveContains(searchText)
        }
        return sortAscending ? filtered : filtered.reversed()
    }
}
