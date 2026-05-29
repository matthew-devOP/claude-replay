import SwiftUI

/// Top-level view for the Chats tab. Mirrors `DashboardView` in shape:
/// the SidebarView (shared with Dashboard) drives `appState.selectedProject`,
/// and this view shows either the welcome state or a session list with
/// Resume/Transcript/Split-view actions per row.
///
/// v0.8.1-swift: split-view chat is now live. Toggling `splitMode` swaps the
/// session list for an `HSplitView` of two independent `ChatView` panes; each
/// pane carries its own `ChatViewModel` (see `ChatView.swift` — `vm` is per-
/// view `@State`, so two instances do not share state).
struct ChatsView: View {
    @Environment(AppState.self) private var appState

    @State private var splitMode: Bool = false
    @State private var primarySessionPath: String? = nil
    @State private var primaryProjectPath: String? = nil
    @State private var secondarySessionPath: String? = nil
    @State private var secondaryProjectPath: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            ChatActiveListView()
            Divider()
            // G16 — multi-tab live chat. The container owns its own
            // session picker / empty-state, so we drop straight in here.
            // The split-view path remains accessible via the picker
            // surfaced inside each tab (ChatSessionListView still drives
            // `splitMode` per-tab when needed).
            ChatTabContainerView()
        }
    }

    // MARK: - Split view

    private var splitView: some View {
        VStack(spacing: 0) {
            splitHeader
            Divider()
            HSplitView {
                pane(
                    sessionPath: $primarySessionPath,
                    projectPath: $primaryProjectPath,
                    label: "Pane A"
                )
                pane(
                    sessionPath: $secondarySessionPath,
                    projectPath: $secondaryProjectPath,
                    label: "Pane B"
                )
            }
        }
    }

    private var splitHeader: some View {
        HStack(spacing: DesignTokens.space12) {
            Image(systemName: "rectangle.split.2x1")
                .foregroundStyle(appState.theme.accent)
            Text("Split-view chats")
                .font(.headline)
            Spacer()
            Button {
                splitMode = false
            } label: {
                Label("Exit split", systemImage: "rectangle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .keyboardShortcut(.escape, modifiers: [])
            .help("Return to the single-pane session list")
        }
        .padding(.horizontal, DesignTokens.space16)
        .padding(.vertical, DesignTokens.space10)
    }

    @ViewBuilder
    private func pane(
        sessionPath: Binding<String?>,
        projectPath: Binding<String?>,
        label: String
    ) -> some View {
        if let path = sessionPath.wrappedValue {
            let project = projectPath.wrappedValue
                ?? appState.selectedProject?.path
                ?? FileManager.default.homeDirectoryForCurrentUser.path
            VStack(spacing: 0) {
                HStack {
                    Text(label)
                        .font(.caption.smallCaps())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        sessionPath.wrappedValue = nil
                        projectPath.wrappedValue = nil
                    } label: {
                        Label("Change session", systemImage: "arrow.left.arrow.right")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .help("Pick a different session for this pane")
                }
                .padding(.horizontal, DesignTokens.space12)
                .padding(.vertical, DesignTokens.space6)
                Divider()
                ChatView(sessionPath: path, projectPath: project)
            }
            .frame(minWidth: 380)
        } else {
            ChatPaneSessionPicker(label: label) { picked, projPath in
                sessionPath.wrappedValue = picked
                projectPath.wrappedValue = projPath
            }
            .frame(minWidth: 380)
        }
    }
}

/// Compact session picker used inside a split-view pane when no session has
/// been chosen yet. Reuses `SessionListViewModel` (same data path as the main
/// chat list) but renders a minimal, dense list to fit a half-pane.
private struct ChatPaneSessionPicker: View {
    @Environment(AppState.self) private var appState
    @State private var vm = SessionListViewModel()
    let label: String
    let onPick: (String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(label) — choose a session")
                    .font(.caption.smallCaps())
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, DesignTokens.space12)
            .padding(.vertical, DesignTokens.space6)
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
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.sessions) { session in
                            Button {
                                let projPath = appState.selectedProject?.path
                                    ?? FileManager.default.homeDirectoryForCurrentUser.path
                                onPick(session.path, projPath)
                            } label: {
                                HStack(spacing: DesignTokens.space10) {
                                    Text(String(session.sessionId.prefix(12)))
                                        .font(.system(.caption, design: .monospaced))
                                    Spacer()
                                    if let date = session.date {
                                        Text(date.shortRelativeString())
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Image(systemName: "play.fill")
                                        .font(.caption2)
                                        .foregroundStyle(appState.theme.accent)
                                }
                                .padding(.horizontal, DesignTokens.space12)
                                .padding(.vertical, DesignTokens.space8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
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
    }
}
