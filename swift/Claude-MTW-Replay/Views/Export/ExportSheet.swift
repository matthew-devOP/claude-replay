import SwiftUI
struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var vm = ExportViewModel()
    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                Text("Export Session").font(.title2).bold()
                Form {
                    Picker("Format", selection: $vm.format) { ForEach(ExportViewModel.ExportFormat.allCases, id: \.self) { Text($0.rawValue.uppercased()).tag($0) } }
                    ThemePickerView(selectedTheme: $vm.theme)
                    Slider(value: $vm.speed, in: 0.5...10, step: 0.5) { Text("Speed: \(vm.speed, specifier: "%.1f")x") }
                }
                HStack { Button("Cancel") { dismiss() }; Spacer(); Button("Export") { Task { /* TODO */ dismiss() } }.buttonStyle(.borderedProminent) }
            }.padding(24).frame(width: 400)
            if vm.isExporting {
                ExportProgressView()
            }
        }
    }
}
