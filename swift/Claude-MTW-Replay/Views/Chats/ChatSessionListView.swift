import SwiftUI

/// Sessions for the project currently selected in the sidebar, with the
/// Chats action column: Transcript / Resume / Split-view.
///
/// - Transcript opens the existing transcript view (no regression)
/// - Resume hands off to ChatView for live continuation
/// - Split-view is disabled in v0.8.0-swift (see plan, deferred to v0.8.1)
///
/// Reuses `SessionListViewModel` (already account-aware after v0.7.4) and
/// loads on project / account changes via `.task(id:)`.
struct ChatSessionListView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = SessionListViewModel()
    @State private var resumingPath: String?
    @State private var transcriptPath: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if vm.isLoading {
                ProgressView("Loading sessions…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.sessions.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: "No sessions",
                    subtitle: "This project has no Claude Code sessions yet."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                sessionsTable
            }
        }
        .task(id: "\(appState.selectedProjectDirName ?? "")|\(appState.claudeAccountDir)") {
            if let dirName = appState.selectedProjectDirName {
                await vm.loadSessions(
                    projectDirName: dirName,
                    source: appState.selectedProjectSource,
                    claudeAccountDir: appState.claudeAccountDir
                )
            }
        }
        .sheet(item: Binding(
            get: { transcriptPath.map(SessionPath.init) },
            set: { transcriptPath = $0?.value }
        )) { wrapped in
            // Open the existing transcript view in a sheet so we don't lose
            // the chats list context. TranscriptView reads from
            // appState.selectedSessionPath, so we set + clear around the sheet.
            TranscriptView()
                .frame(minWidth: 800, minHeight: 600)
                .onAppear { appState.selectedSessionPath = wrapped.value }
        }
        .sheet(item: Binding(
            get: { resumingPath.map(SessionPath.init) },
            set: { resumingPath = $0?.value }
        )) { wrapped in
            ChatView(
                sessionPath: wrapped.value,
                projectPath: appState.selectedProject?.path ?? FileManager.default.homeDirectoryForCurrentUser.path
            )
            .frame(minWidth: 900, minHeight: 700)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var header: some View {
        if let project = appState.selectedProject {
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.title2)
                    .fontWeight(.bold)
                HStack(spacing: 12) {
                    Text(project.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    if !vm.sessions.isEmpty {
                        Text("• \(vm.sessions.count) session\(vm.sessions.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private var sessionsTable: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(vm.sessions) { session in
                    ChatSessionRow(
                        session: session,
                        onTranscript: { transcriptPath = session.path },
                        onResume: { resumingPath = session.path }
                    )
                    Divider()
                }
            }
        }
    }
}

/// Tiny Identifiable wrapper so a `String` session path drives a `.sheet(item:)`.
private struct SessionPath: Identifiable {
    let value: String
    var id: String { value }
    init(_ value: String) { self.value = value }
}

/// One row in the Chats sessions list. Row layout mirrors the Dashboard
/// session table but keeps actions visible inline rather than menu-hidden.
private struct ChatSessionRow: View {
    @Environment(AppState.self) private var appState
    let session: SessionEntry
    let onTranscript: () -> Void
    let onResume: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(session.sessionId.prefix(12)))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
                HStack(spacing: 10) {
                    if let date = session.date {
                        Text(date.shortRelativeString())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(session.size.formattedFileSize())
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                Button(action: onTranscript) {
                    Label("Transcript", systemImage: "doc.text")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: onResume) {
                    Label("Resume", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(appState.theme.accent)

                Button {} label: {
                    Label("Split", systemImage: "rectangle.split.2x1")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(true)
                .help("Split-view will land in v0.8.1-swift")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}
