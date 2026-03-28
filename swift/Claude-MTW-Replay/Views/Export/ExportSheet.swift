import SwiftUI
struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var vm = ExportViewModel()
    @State private var theme = "tokyo-night"
    @State private var speed = 1.0
    var body: some View {
        VStack(spacing: 16) {
            Text("Export Session").font(.title2).bold()
            Form {
                Picker("Format", selection: $vm.format) { ForEach(ExportViewModel.ExportFormat.allCases, id: \.self) { Text($0.rawValue.uppercased()).tag($0) } }
                ThemePickerView(selectedTheme: $theme)
                Slider(value: $speed, in: 0.5...10, step: 0.5) { Text("Speed: \(speed, specifier: "%.1f")x") }
            }
            HStack { Button("Cancel") { dismiss() }; Spacer(); Button("Export") { Task { /* TODO */ dismiss() } }.buttonStyle(.borderedProminent) }
        }.padding(24).frame(width: 400)
    }
}
