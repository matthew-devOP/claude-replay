import SwiftUI
struct SessionTableView: View {
    let sessions: [SessionEntry]
    @Environment(AppState.self) private var appState
    var body: some View {
        Table(sessions) {
            TableColumn("Session ID") { s in Text(String(s.sessionId.prefix(12))).font(.system(.body, design: .monospaced)) }
            TableColumn("Date") { s in Text(s.date?.shortRelativeString() ?? "-") }
            TableColumn("Size") { s in Text(s.size.formattedFileSize()) }
        }
        .onTapGesture(count: 2) {} // placeholder for double-click
    }
}
