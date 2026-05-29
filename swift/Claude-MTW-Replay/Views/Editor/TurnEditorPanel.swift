import SwiftUI
struct TurnEditorPanel: View {
    @Bindable var vm: EditorViewModel
    var body: some View {
        if let idx = vm.selectedTurnIndex, idx < vm.workingTurns.count {
            VStack(alignment: .leading, spacing: DesignTokens.space12) {
                Text("Turn \(idx + 1)").font(.headline)
                Text("User message:").font(.caption).bold()
                TextEditor(text: Binding(get: { vm.workingTurns[idx].userText }, set: { vm.editTurnText(index: idx, newText: $0) }))
                    .font(.body).frame(minHeight: 100)
                Text("Blocks: \(vm.workingTurns[idx].blocks.count)").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Reset") { vm.reset() }.disabled(!vm.hasEdits)
                    Spacer()
                    if vm.hasEdits { Text("Modified").font(.caption).foregroundStyle(.orange) }
                }
            }.padding()
        } else {
            EmptyStateView(icon: "pencil", title: "Select a Turn", subtitle: "Click a turn on the left to edit")
        }
    }
}
