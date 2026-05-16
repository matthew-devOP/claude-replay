import SwiftUI

/// G1 — compact "Active Chats" disclosure shown at the top of the Chats
/// tab. Lists recent sessions whose transcripts have been persisted to
/// SwiftData, so the user can jump back into an in-flight conversation
/// even after relaunching the app.
struct ChatActiveListView: View {
    @Environment(AppState.self) private var appState
    @State private var entities: [ChatTranscriptEntity] = []
    @State private var expanded: Bool = true

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            if entities.isEmpty {
                Text("No recent chats")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(entities, id: \.sessionPath) { entity in
                        Button {
                            appState.selectSession(entity.sessionPath)
                        } label: {
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entity.displayName
                                         ?? URL(fileURLWithPath: entity.sessionPath).lastPathComponent)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Text(entity.lastUpdated.formatted(.relative(presentation: .named)))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if entity.costUsd > 0 {
                                    Text(String(format: "$%.3f", entity.costUsd))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .font(.caption)
                Text("Active Chats")
                    .font(.caption.smallCaps())
                if !entities.isEmpty {
                    Text("(\(entities.count))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .task { entities = DataStore.shared.getRecentChatTranscripts() }
    }
}
