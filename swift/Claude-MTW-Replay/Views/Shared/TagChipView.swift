import SwiftUI
struct TagChipView: View {
    let tag: String; var onRemove: (() -> Void)? = nil
    var body: some View {
        HStack(spacing: 4) {
            Text(tag).font(.caption2)
            if let onRemove { Button { onRemove() } label: { Image(systemName: "xmark").font(.caption2) } .buttonStyle(.plain) }
        }.padding(.horizontal, 6).padding(.vertical, 2).background(Color(hex: "#bb9af7").opacity(0.2), in: Capsule())
    }
}
