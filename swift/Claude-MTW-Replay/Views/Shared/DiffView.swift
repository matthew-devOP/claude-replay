import SwiftUI
struct DiffView: View {
    let oldText: String; let newText: String; var filePath: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let fp = filePath { Text(fp).font(.caption).foregroundStyle(.secondary).padding(4) }
            VStack(alignment: .leading, spacing: 1) {
                ForEach(oldText.components(separatedBy: "\n"), id: \.self) { line in
                    Text("- \(line)").font(.system(.caption, design: .monospaced)).foregroundStyle(Color(hex: "#f7768e")).padding(.horizontal, 4).background(Color(hex: "#f7768e").opacity(0.1))
                }
                ForEach(newText.components(separatedBy: "\n"), id: \.self) { line in
                    Text("+ \(line)").font(.system(.caption, design: .monospaced)).foregroundStyle(Color(hex: "#9ece6a")).padding(.horizontal, 4).background(Color(hex: "#9ece6a").opacity(0.1))
                }
            }.padding(4)
        }.background(Color(hex: "#1e1f33"), in: RoundedRectangle(cornerRadius: 6))
    }
}
