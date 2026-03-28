import SwiftUI
struct SessionRowView: View {
    let session: SessionEntry
    var body: some View {
        HStack {
            Text(String(session.sessionId.prefix(8))).font(.system(.body, design: .monospaced))
            Spacer()
            Text(session.date?.shortRelativeString() ?? "").font(.caption).foregroundStyle(.secondary)
            Text(session.size.formattedFileSize()).font(.caption).foregroundStyle(.secondary)
        }
    }
}
