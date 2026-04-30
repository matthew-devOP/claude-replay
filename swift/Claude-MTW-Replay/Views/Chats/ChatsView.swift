import SwiftUI

/// Top-level view for the Chats tab. Mirrors `DashboardView` in shape:
/// the SidebarView (shared with Dashboard) drives `appState.selectedProject`,
/// and this view shows either the welcome state or a session list with
/// Resume/Transcript/Split-view actions per row.
///
/// Step 2 of the v0.8.0-swift plan: this is intentionally a thin placeholder
/// so the tab is reachable end-to-end. Step 3 fills in `ChatSessionListView`,
/// step 7 the live `ChatView`.
struct ChatsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.selectedProject != nil {
                ChatSessionListView()
            } else {
                EmptyStateView(
                    icon: "bubble.left.and.exclamationmark.bubble.right",
                    title: "Pick a project to chat",
                    subtitle: "Choose a project from the sidebar to see its sessions, then hit Resume on the one you want to continue."
                )
            }
        }
    }
}
