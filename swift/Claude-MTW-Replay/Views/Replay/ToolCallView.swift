import SwiftUI
struct ToolCallView: View {
    @Environment(AppState.self) private var appState
    let block: AssistantBlock
    @State private var isExpanded = false
    var body: some View {
        if let tc = block.toolCall {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 4) {
                    if let cmd = tc.input["command"]?.stringValue, tc.name == "Bash" {
                        CodeBlockView(code: cmd, language: "bash")
                    }
                    if tc.name == "Edit",
                       let oldStr = tc.input["old_string"]?.stringValue,
                       let newStr = tc.input["new_string"]?.stringValue {
                        DiffView(oldText: oldStr, newText: newStr, filePath: tc.input["file_path"]?.stringValue)
                    }
                    if let result = tc.result {
                        Text(result).font(.system(.caption, design: .monospaced)).foregroundStyle(tc.isError ? appState.theme.red : appState.theme.green).lineLimit(20)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Circle().fill(tc.isError ? appState.theme.red : appState.theme.blue).frame(width: 8, height: 8)
                    Text(tc.name).font(.caption).bold().foregroundStyle(appState.theme.cyan)
                    Text(toolPreview(tc)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .padding(8).background(appState.theme.toolBg, in: RoundedRectangle(cornerRadius: 6))
        }
    }
    private func toolPreview(_ tc: ToolCall) -> String {
        switch tc.name {
        case "Bash": return tc.input["command"]?.stringValue?.components(separatedBy: "\n").first ?? ""
        case "Read", "Write", "Edit": return tc.input["file_path"]?.stringValue ?? ""
        case "Grep": return tc.input["pattern"]?.stringValue ?? ""
        default: return tc.input.first?.key ?? tc.name
        }
    }
}
