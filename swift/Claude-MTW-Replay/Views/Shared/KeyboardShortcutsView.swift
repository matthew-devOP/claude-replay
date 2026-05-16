import SwiftUI
struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) private var dismiss

    private let playbackShortcuts: [(String, String)] = [
        ("Space / K", "Play / Pause"),
        ("→ / L", "Step forward"),
        ("← / H", "Step back"),
        ("⇧→", "Next turn"),
        ("⇧←", "Previous turn"),
        ("T", "Toggle thinking blocks"),
        ("Escape", "Stop playback"),
    ]

    private let globalShortcuts: [(String, String)] = [
        ("⌘F", "Search"),
        ("⌘E", "Export"),
        ("↑/↓", "Navigate sidebar / sessions"),
        ("Enter", "Open selected"),
        ("?", "This help"),
    ]

    private var tabShortcuts: [(String, String)] {
        AppTab.allCases.enumerated().map { idx, tab in
            ("⌘\(idx + 1)", "Switch to \(tab.label)")
        }
    }

    private var shortcuts: [(String, String)] {
        playbackShortcuts + tabShortcuts + globalShortcuts
    }

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
