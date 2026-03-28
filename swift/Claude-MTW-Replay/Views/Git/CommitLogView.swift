import SwiftUI
struct CommitLogView: View {
    let details: GitDetails
    var body: some View {
        VStack(alignment: .leading) {
            Text("Recent Commits (\(details.commitCount) total)").font(.headline)
            ForEach(details.recentCommits) { c in
                HStack { Text(c.hash).font(.system(.caption, design: .monospaced)).foregroundStyle(Color(hex: "#7aa2f7")); Text(c.message).lineLimit(1); Spacer(); Text(c.date).font(.caption2).foregroundStyle(.secondary) }
            }
        }
    }
}
