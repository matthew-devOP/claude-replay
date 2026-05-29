import SwiftUI
struct ReplayControlsView: View {
    @Environment(AppState.self) private var appState
    @Bindable var vm: ReplayViewModel
    var body: some View {
        VStack(spacing: DesignTokens.space8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(appState.theme.border).frame(height: 4)
                    Rectangle().fill(appState.theme.accent).frame(width: geo.size.width * vm.progress, height: 4)
                }.frame(height: 6).clipShape(Capsule())
                .onTapGesture { location in
                    let pct = location.x / geo.size.width
                    vm.seekToTurn(max(1, Int(pct * Double(vm.turns.count))))
                }
                .accessibilityElement()
                .accessibilityLabel("Replay progress")
                .accessibilityValue("Turn \(vm.currentTurnIndex) of \(vm.turns.count)")
                .accessibilityHint("Tap to seek")
            }.frame(height: 6).padding(.horizontal)
            HStack(spacing: DesignTokens.space16) {
                // Transport cluster — a floating glass capsule on macOS 26,
                // a plain themed cluster below it.
                HStack(spacing: DesignTokens.space16) {
                    Button { vm.prevTurn() } label: { Image(systemName: "backward.fill") }
                        .accessibilityLabel("Previous turn")
                        .accessibilityHint("Jump to the previous turn")
                    Button { vm.togglePlay() } label: { Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill") }
                        .font(.title2)
                        .accessibilityLabel(vm.isPlaying ? "Pause" : "Play")
                        .accessibilityHint("Toggle replay playback (Space)")
                    Button { vm.nextTurn() } label: { Image(systemName: "forward.fill") }
                        .accessibilityLabel("Next turn")
                        .accessibilityHint("Jump to the next turn")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, DesignTokens.spaceMD + 2)
                .padding(.vertical, DesignTokens.spaceSM - 2)
                .appGlass(in: Capsule(), fallback: appState.theme.bgSurface, interactive: true)
                Spacer()
                Text("Turn \(vm.currentTurnIndex)/\(vm.turns.count)").font(.caption).monospacedDigit()
                Picker("Speed", selection: $vm.speed) {
                    ForEach(ReplayViewModel.speedSteps, id: \.self) { s in Text("\(s, specifier: "%.1f")x").tag(s) }
                }.frame(width: 80)
                Toggle("Thinking", isOn: $vm.showThinking).toggleStyle(.button).font(.caption)
                Toggle("Tools", isOn: $vm.showToolCalls).toggleStyle(.button).font(.caption)
            }
            .padding(.horizontal).padding(.bottom, DesignTokens.spaceSM)
            .glassGroup()
        }
        .background(appState.theme.bgSurface)
        .onKeyPress(.space) { vm.togglePlay(); return .handled }
        .onKeyPress(.rightArrow) { vm.stepForward(); return .handled }
        .onKeyPress(.leftArrow) { vm.stepBack(); return .handled }
    }
}
