import SwiftUI
struct ReplayControlsView: View {
    @Environment(AppState.self) private var appState
    @Bindable var vm: ReplayViewModel
    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(appState.theme.border).frame(height: 4)
                    Rectangle().fill(appState.theme.accent).frame(width: geo.size.width * vm.progress, height: 4)
                }.frame(height: 6).clipShape(Capsule())
                .onTapGesture { location in
                    let pct = location.x / geo.size.width
                    vm.seekToTurn(max(1, Int(pct * Double(vm.turns.count))))
                }
            }.frame(height: 6).padding(.horizontal)
            HStack(spacing: 16) {
                Button { vm.prevTurn() } label: { Image(systemName: "backward.fill") }
                Button { vm.togglePlay() } label: { Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill") }.font(.title2)
                Button { vm.nextTurn() } label: { Image(systemName: "forward.fill") }
                Spacer()
                Text("Turn \(vm.currentTurnIndex)/\(vm.turns.count)").font(.caption).monospacedDigit()
                Picker("Speed", selection: $vm.speed) {
                    ForEach(ReplayViewModel.speedSteps, id: \.self) { s in Text("\(s, specifier: "%.1f")x").tag(s) }
                }.frame(width: 80)
                Toggle("Thinking", isOn: $vm.showThinking).toggleStyle(.button).font(.caption)
                Toggle("Tools", isOn: $vm.showToolCalls).toggleStyle(.button).font(.caption)
            }.padding(.horizontal).padding(.bottom, 8)
        }
        .background(appState.theme.bgSurface)
        .onKeyPress(.space) { vm.togglePlay(); return .handled }
        .onKeyPress(.rightArrow) { vm.stepForward(); return .handled }
        .onKeyPress(.leftArrow) { vm.stepBack(); return .handled }
    }
}
