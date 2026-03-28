import SwiftUI
struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) private var dismiss
    let shortcuts: [(String, String)] = [
        ("Space", "Play / Pause"), ("→", "Step forward"), ("←", "Step back"),
        ("⇧→", "Next turn"), ("⇧←", "Previous turn"), ("⌘1-6", "Switch tabs"),
        ("⌘F", "Search"), ("⌘E", "Export"), ("?", "This help")
    ]
    var body: some View {
        VStack(spacing: 16) {
            Text("Keyboard Shortcuts").font(.title2).bold()
            LazyVGrid(columns: [GridItem(.fixed(100)), GridItem(.flexible())], spacing: 8) {
                ForEach(shortcuts, id: \.0) { key, desc in
                    Text(key).font(.system(.body, design: .monospaced)).frame(maxWidth: .infinity, alignment: .trailing)
                    Text(desc).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Button("Close") { dismiss() }.keyboardShortcut(.escape, modifiers: [])
        }.padding(24).frame(width: 400)
    }
}
