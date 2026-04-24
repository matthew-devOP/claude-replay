import SwiftUI
struct GitActionsView: View {
    let projectPath: String
    var body: some View {
        HStack {
            Button { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: projectPath) } label: { Label("Open in Finder", systemImage: "folder") }
            Button { openInTerminal() } label: { Label("Open in Terminal", systemImage: "terminal") }
        }
    }
    private func openInTerminal() {
        let escaped = projectPath
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"Terminal\" to do script \"cd \\\"\(escaped)\\\"\""
        if let appleScript = NSAppleScript(source: script) { appleScript.executeAndReturnError(nil) }
    }
}
