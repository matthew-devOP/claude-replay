import SwiftUI
struct ThemePickerView: View {
    @Binding var selectedTheme: String
    var body: some View {
        Picker("Theme", selection: $selectedTheme) {
            ForEach(ThemeService.listThemes(), id: \.self) { name in Text(name).tag(name) }
        }
    }
}
