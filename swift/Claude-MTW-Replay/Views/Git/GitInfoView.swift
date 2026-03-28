import SwiftUI
struct GitInfoView: View {
    let info: GitInfo
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("Branch:").bold(); Text(info.branch ?? "detached").font(.system(.body, design: .monospaced)) }
            HStack { Text("Status:").bold(); Text(info.status.isClean ? "Clean" : "\(info.status.modified)M \(info.status.added)A \(info.status.deleted)D").foregroundStyle(info.status.isClean ? .green : .orange) }
            if !info.remotes.isEmpty { HStack { Text("Remotes:").bold(); Text(info.remotes.joined(separator: ", ")) } }
        }
    }
}
