import SwiftUI
struct TurnBrowserPanel: View {
    @Bindable var vm: EditorViewModel
    var body: some View {
        List(selection: $vm.selectedTurnIndex) {
            ForEach(Array(vm.workingTurns.enumerated()), id: \.offset) { index, turn in
                HStack {
                    Toggle("", isOn: Binding(get: { !vm.excludedTurns.contains(index) }, set: { _ in vm.toggleExclude(index: index) }))
                    VStack(alignment: .leading) {
                        Text("Turn \(index + 1)").font(.caption).bold()
                        Text(turn.userText).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                    }
                }.tag(index)
            }
        }.navigationTitle("Turns")
    }
}
