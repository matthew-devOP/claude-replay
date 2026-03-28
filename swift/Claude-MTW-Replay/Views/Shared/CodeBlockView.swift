import SwiftUI
struct CodeBlockView: View {
    let code: String; var language: String = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !language.isEmpty { Text(language).font(.caption2).foregroundStyle(.secondary).padding(.horizontal, 8).padding(.top, 4) }
            ScrollView(.horizontal) { Text(code).font(.system(.caption, design: .monospaced)).textSelection(.enabled).padding(8) }
        }.background(Color(hex: "#1a1b26"), in: RoundedRectangle(cornerRadius: 6)).overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#3b3d57"), lineWidth: 1))
    }
}
