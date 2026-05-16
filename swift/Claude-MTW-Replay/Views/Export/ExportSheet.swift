import SwiftUI

struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var vm = ExportViewModel()
    @State private var userLabel: String = "Human"
    @State private var assistantLabel: String = "Assistant"
    @State private var redactSecrets: Bool = true
    @State private var title: String = ""
    @State private var showError = false

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                Text("Export Session").font(.title2).bold()
                Form {
                    Picker("Format", selection: $vm.format) {
                        ForEach(ExportViewModel.ExportFormat.allCases, id: \.self) {
                            Text($0.rawValue.uppercased()).tag($0)
                        }
                    }
                    ThemePickerView(selectedTheme: $vm.theme)
                    Picker("Speed", selection: $vm.speed) {
                        ForEach(ReplayViewModel.speedSteps, id: \.self) { step in
                            Text("\(step, specifier: step == Double(Int(step)) ? "%.0f" : "%.1f")x").tag(step)
                        }
                    }
                    .pickerStyle(.segmented)
                    TextField("Title", text: $title)
                    TextField("User label", text: $userLabel)
                    TextField("Assistant label", text: $assistantLabel)
                    Toggle("Redact secrets", isOn: $redactSecrets)
                }
                HStack {
                    Button("Cancel") { dismiss() }
                    Spacer()
                    Button("Export") {
                        Task {
                            let turns = await currentTurns()
                            await vm.export(turns: turns, options: makeOptions())
                            if vm.errorMessage == nil {
                                dismiss()
                            } else {
                                showError = true
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.isExporting)
                }
            }
            .padding(24)
            .frame(width: 400)

            if vm.isExporting {
                ExportProgressView()
            }
        }
        .onChange(of: vm.errorMessage) { _, new in
            showError = (new != nil)
        }
        .alert("Export failed", isPresented: $showError) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private func currentTurns() async -> [Turn] {
        guard let path = appState.selectedSessionPath else { return [] }
        do {
            let text = try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
            return TranscriptParser.parseTranscriptFromText(text)
        } catch {
            return []
        }
    }

    private func makeOptions() -> ExportOptions {
        let themeName = ThemeName(rawValue: vm.theme) ?? .tokyoNight
        var opts = ExportOptions.default
        opts.theme = themeName
        opts.speed = vm.speed
        opts.userLabel = userLabel
        opts.assistantLabel = assistantLabel
        opts.title = title
        opts.redactSecrets = redactSecrets
        return opts
    }
}
