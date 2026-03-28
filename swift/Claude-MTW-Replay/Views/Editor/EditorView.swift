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
    }
}
