import SwiftUI
struct EditorView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = EditorViewModel()
    var body: some View {
        HSplitView {
            TurnBrowserPanel(vm: vm).frame(minWidth: 200)
            TurnEditorPanel(vm: vm).frame(minWidth: 300)
        }
        .task(id: appState.selectedSessionPath) {
            if let p = appState.selectedSessionPath { await vm.loadSession(path: URL(fileURLWithPath: p)) }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Discard Changes") { vm.discardChanges() }
                    .help("Revert all edits and exclusions for this session")
                    .disabled(!vm.hasEdits)
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    appState.showDoc(topicId: "editor")
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .help("Editor documentation")
            }
        }
    }
}
