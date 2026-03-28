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
                Slider(value: $defaultSpeed, in: 0.5...20, step: 0.5) { Text("Speed: \(defaultSpeed, specifier: "%.1f")x") }
                Toggle("Show thinking blocks", isOn: $showThinking)
                Toggle("Show tool calls", isOn: $showTools)
            }
            Section("Security") {
                Toggle("Auto-redact secrets", isOn: $autoRedact)
            }
        }.formStyle(.grouped).frame(width: 450)
    }
}
