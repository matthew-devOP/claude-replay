import SwiftUI
struct ToolCallView: View {
    let block: AssistantBlock
    @State private var isExpanded = false
    var body: some View {
        if let tc = block.toolCall {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 4) {
                    if let cmd = tc.input["command"]?.stringValue, tc.name == "Bash" {
                        CodeBlockView(code: cmd, language: "bash")
                    }
                    if let result = tc.result {
                        Text(result).font(.system(.caption, design: .monospaced)).foregroundStyle(tc.isError ? Color(hex: "#f7768e") : Color(hex: "#9ece6a")).lineLimit(20)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Circle().fill(tc.isError ? Color(hex: "#f7768e") : Color(hex: "#7aa2f7")).frame(width: 8, height: 8)
                    Text(tc.name).font(.caption).bold().foregroundStyle(Color(hex: "#7dcfff"))
                    Text(toolPreview(tc)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .padding(8).background(Color(hex: "#1e1f33"), in: RoundedRectangle(cornerRadius: 6))
        }
    }
    private func toolPreview(_ tc: ToolCall) -> String {
        switch tc.name {
        case "Bash": return tc.input["command"]?.stringValue?.components(separatedBy: "\n").first ?? ""
        case "Read", "Write", "Edit": return tc.input["file_path"]?.stringValue ?? ""
        case "Grep": return tc.input["pattern"]?.stringValue ?? ""
        default: return ""
        }
    }
}
