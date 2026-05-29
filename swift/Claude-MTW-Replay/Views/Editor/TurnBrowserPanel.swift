import SwiftUI
struct TurnBrowserPanel: View {
    @Bindable var vm: EditorViewModel
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Include All") { vm.includeAllTurns() }
                Button("Exclude All") { vm.excludeAllTurns() }
                Spacer()
            }
            .padding(.horizontal, DesignTokens.space8)
            .padding(.vertical, DesignTokens.space6)
            List(selection: $vm.selectedTurnIndex) {
                ForEach(Array(vm.workingTurns.enumerated()), id: \.offset) { index, turn in
                    HStack {
                        Toggle("", isOn: Binding(get: { !vm.excludedTurns.contains(index) }, set: { _ in vm.toggleExclude(index: index) }))
                        VStack(alignment: .leading) {
                            Text("Turn \(index + 1)").font(.caption).bold()
                            Text(turn.userText).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                    .tag(index)
                    .contextMenu {
                        Button("Exclude before this") { vm.excludeBefore(index: index) }
                        Button("Exclude after this") { vm.excludeAfter(index: index) }
                        Button("Exclude this turn") { vm.toggleExclude(index: index) }
                    }
                }
            }
        }
        .navigationTitle("Turns")
    }
}
