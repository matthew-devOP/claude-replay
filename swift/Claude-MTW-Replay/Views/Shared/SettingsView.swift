import SwiftUI
struct SettingsView: View {
    @AppStorage("defaultTheme") private var defaultTheme = "tokyo-night"
    @AppStorage("defaultSpeed") private var defaultSpeed = 1.0
    @AppStorage("showThinkingByDefault") private var showThinking = true
    @AppStorage("showToolCallsByDefault") private var showTools = true
    @AppStorage("autoRedactSecrets") private var autoRedact = true
    var body: some View {
        Form {
            Section("Playback") {
                Picker("Default Theme", selection: $defaultTheme) {
                    ForEach(ThemeService.listThemes(), id: \.self) { Text($0).tag($0) }
                }
                Picker("Speed", selection: $defaultSpeed) {
                    ForEach(ReplayViewModel.speedSteps, id: \.self) { step in
                        Text("\(step, specifier: step == Double(Int(step)) ? "%.0f" : "%.1f")x").tag(step)
                    }
                }
                Toggle("Show thinking blocks", isOn: $showThinking)
                Toggle("Show tool calls", isOn: $showTools)
            }
            Section("Security") {
                Toggle("Auto-redact secrets", isOn: $autoRedact)
            }
        }.formStyle(.grouped).frame(width: 450)
    }
}
