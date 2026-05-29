import SwiftUI

/// G16 — Multi-tab live chat container.
///
/// Owns a list of `ChatTab` rows (each = one session + one `ChatView`
/// instance) and renders:
///
///   ┌─ tab strip ──────────────────────────┐
///   │ [ tab A ] [ tab B ]…  [+]             │
///   ├──────────────────────────────────────┤
///   │ active tab's ChatView (or picker)    │
///   └──────────────────────────────────────┘
///
/// Each tab is keyed by `UUID`; we slap `.id(tab.id)` on the rendered
/// `ChatView` so SwiftUI fully re-inits its `@State private var vm:
/// ChatViewModel` when the user switches tabs — that preserves the
/// "one ChatViewModel per session" invariant the rest of the chat
/// pipeline relies on.
///
/// Drop-in: lives inside `ChatsView`'s existing `VStack` *under* the
/// `ChatActiveListView` strip added by Sprint 4-A. The container itself
/// does *not* render the active-chats strip.
struct ChatTabContainerView: View {
    @Environment(AppState.self) private var appState

    /// A tab tracks its session + project paths so each ChatView can spawn
    /// its own ChatViewModel. `sessionPath == nil` means "no session
    /// chosen yet" — we fall through to the standard `ChatSessionListView`
    /// picker for this tab.
    struct ChatTab: Identifiable, Equatable {
        let id: UUID
        var sessionPath: String?
        var projectPath: String?
        var displayName: String

        init(
            id: UUID = UUID(),
            sessionPath: String? = nil,
            projectPath: String? = nil,
            displayName: String = "New chat"
        ) {
            self.id = id
            self.sessionPath = sessionPath
            self.projectPath = projectPath
            self.displayName = displayName
        }
    }

    @State private var tabs: [ChatTab]
    @State private var activeId: UUID
    // Local mirrors of the per-tab session/project so `ChatSessionListView`
    // can write into them as the user picks a row. We translate between
    // these bindings and `tabs[activeIndex]` in the relevant view-builders.
    @State private var pickerSessionPath: String? = nil
    @State private var pickerProjectPath: String? = nil
    // Split-mode is opt-in per tab and lives inside `ChatSessionListView`,
    // but we still need a binding for it. Container-level split is a future
    // enhancement; for now we keep one shared flag (off by default).
    @State private var splitMode: Bool = false

    init() {
        let first = ChatTab()
        _tabs = State(initialValue: [first])
        _activeId = State(initialValue: first.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            tabStrip
            Divider()
            activeContent
        }
        // When the user picks a session via the embedded session list, the
        // bindings update and we commit the choice into the active tab.
        .onChange(of: pickerSessionPath) { _, newPath in
            commitPickedSession(path: newPath, projectPath: pickerProjectPath)
        }
        // When the AppState's chat-resume hook fires (Replay → "Continue
        // live"), open the resumed session in the active tab.
        .onChange(of: appState.resumingChatPath) { _, newPath in
            guard let path = newPath else { return }
            let projPath = appState.selectedProject?.path
                ?? FileManager.default.homeDirectoryForCurrentUser.path
            commitPickedSession(path: path, projectPath: projPath)
            appState.resumingChatPath = nil
        }
    }

    // MARK: - Tab strip

    private var tabStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.space4) {
                ForEach(tabs) { tab in
                    chip(for: tab)
                }
                Button {
                    addNewTab()
                } label: {
                    Image(systemName: "plus")
                        .font(.caption)
                        .padding(.horizontal, DesignTokens.space6)
                        .padding(.vertical, DesignTokens.space4)
                }
                .buttonStyle(.plain)
                .help("Open a new chat tab")
            }
            .padding(.horizontal, DesignTokens.space8)
            .padding(.vertical, DesignTokens.space4)
        }
        .background(appState.theme.bg.opacity(0.4))
    }

    @ViewBuilder
    private func chip(for tab: ChatTab) -> some View {
        HStack(spacing: DesignTokens.space6) {
            Image(systemName: tab.sessionPath == nil
                  ? "plus.bubble"
                  : "bubble.left.and.exclamationmark.bubble.right")
                .font(.caption2)
                .foregroundStyle(activeId == tab.id ? appState.theme.accent : .secondary)
            Text(tab.displayName)
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: 160, alignment: .leading)
            if tabs.count > 1 {
                Button {
                    closeTab(tab.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Close this tab")
            }
        }
        .padding(.horizontal, DesignTokens.space8)
        .padding(.vertical, DesignTokens.space4)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.cornerSmall)
                .fill(activeId == tab.id
                      ? appState.theme.accent.opacity(0.18)
                      : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { selectTab(tab.id) }
    }

    // MARK: - Active content

    @ViewBuilder
    private var activeContent: some View {
        if let active = tabs.first(where: { $0.id == activeId }) {
            if let session = active.sessionPath {
                let project = active.projectPath
                    ?? appState.selectedProject?.path
                    ?? FileManager.default.homeDirectoryForCurrentUser.path
                ChatView(sessionPath: session, projectPath: project)
                    // .id forces SwiftUI to tear down the previous
                    // ChatViewModel and stand up a fresh one when the
                    // active tab changes — exactly what we want, since
                    // each tab is a logically independent chat.
                    .id(active.id)
            } else {
                // No session in this tab — reuse the existing session
                // list view (project-aware, account-aware) so picking a
                // row materialises into a real chat in *this* tab.
                if appState.selectedProject != nil {
                    ChatSessionListView(
                        splitMode: $splitMode,
                        primarySessionPath: $pickerSessionPath,
                        primaryProjectPath: $pickerProjectPath
                    )
                } else {
                    EmptyStateView(
                        icon: "bubble.left.and.exclamationmark.bubble.right",
                        title: "Pick a project to chat",
                        subtitle: "Choose a project from the sidebar to see its sessions, then hit Resume on the one you want to continue."
                    )
                }
            }
        } else {
            // Defensive: no active tab. Reset.
            EmptyStateView(
                icon: "tray",
                title: "No active tab",
                subtitle: "Open a new tab to start chatting."
            )
            .onAppear { addNewTab() }
        }
    }

    // MARK: - Mutations

    private func addNewTab() {
        let new = ChatTab()
        tabs.append(new)
        activeId = new.id
        // Reset picker bindings so the new tab starts in "pick a session" mode.
        pickerSessionPath = nil
        pickerProjectPath = nil
    }

    private func closeTab(_ id: UUID) {
        guard tabs.count > 1 else { return }
        let index = tabs.firstIndex(where: { $0.id == id }) ?? 0
        let wasActive = (activeId == id)
        tabs.removeAll { $0.id == id }
        if wasActive {
            activeId = tabs[max(0, index - 1)].id
            // Re-sync picker bindings to whatever tab we landed on.
            if let landed = tabs.first(where: { $0.id == activeId }) {
                pickerSessionPath = landed.sessionPath
                pickerProjectPath = landed.projectPath
            }
        }
    }

    private func selectTab(_ id: UUID) {
        guard id != activeId else { return }
        activeId = id
        if let target = tabs.first(where: { $0.id == id }) {
            pickerSessionPath = target.sessionPath
            pickerProjectPath = target.projectPath
        }
    }

    /// Lift a session/project pair (picked via the session list, or pushed
    /// by `AppState.resumingChatPath`) into the currently-active tab.
    private func commitPickedSession(path: String?, projectPath: String?) {
        guard let path = path,
              let activeIndex = tabs.firstIndex(where: { $0.id == activeId }) else { return }
        // Avoid clobbering a tab that already points at this session
        // (e.g. when ChatSessionListView re-emits the same binding on
        // rebuild, which would otherwise nuke our display name).
        if tabs[activeIndex].sessionPath == path { return }
        var updated = tabs[activeIndex]
        updated.sessionPath = path
        updated.projectPath = projectPath
        updated.displayName = Self.shortLabel(forSessionPath: path)
        tabs[activeIndex] = updated
    }

    private static func shortLabel(forSessionPath path: String) -> String {
        let last = (path as NSString).lastPathComponent
            .replacingOccurrences(of: ".jsonl", with: "")
        return String(last.prefix(10))
    }
}
