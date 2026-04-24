import SwiftUI
struct SessionTableView: View {
    let sessions: [SessionEntry]
    @Binding var sortAscending: Bool
    @Environment(AppState.self) private var appState
    @State private var selection: SessionEntry.ID?
    @State private var sortOrder = [KeyPathComparator(\SessionEntry.sessionId)]

    var body: some View {
        Table(sessions, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Session ID", value: \.sessionId) { s in
                Text(String(s.sessionId.prefix(12))).font(.system(.body, design: .monospaced))
            }
            TableColumn("Date", value: \.size) { s in
                // Sort by size as proxy since Date? is not directly sortable
                Text(s.date?.shortRelativeString() ?? "-")
            }
            TableColumn("Size", value: \.size) { s in Text(s.size.formattedFileSize()) }
        }
        .onChange(of: sortOrder) { _, newOrder in
            sortAscending = newOrder.first?.order == .forward
        }
        .onChange(of: selection) { _, newValue in
            if let id = newValue, let session = sessions.first(where: { $0.id == id }) {
                appState.selectSession(session.path)
            }
        }
    }
}
