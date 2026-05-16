import SwiftUI

/// G9 — a compact capsule shown in the attachment bar above the chat
/// input. Tapping the chip body opens the preview sheet; the trailing
/// "x" removes the attachment from the pending list without sending it.
struct ChatAttachmentChip: View {
    let attachment: ChatAttachment
    let onRemove: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2)
            Text(attachment.displayName)
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: 120)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill").font(.caption2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Remove attachment \(attachment.displayName)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.15))
        .clipShape(Capsule())
        .contentShape(Capsule())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Attachment: \(attachment.displayName)")
        .accessibilityHint("Tap to preview")
    }

    private var icon: String {
        switch attachment.kind {
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .text: return "doc.text"
        case .other: return "doc"
        }
    }
}
