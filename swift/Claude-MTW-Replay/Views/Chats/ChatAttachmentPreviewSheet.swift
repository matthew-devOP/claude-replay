import SwiftUI
import PDFKit

/// G10 — a modal sheet that previews a staged attachment before it's
/// folded into the outbound prompt. Mac-only: uses `PDFKit` directly
/// for PDFs and SwiftUI's `AsyncImage` for raster images. Code and
/// text files are loaded as UTF-8 and shown in a monospaced scroll
/// view; everything else falls back to an "unsupported" placeholder.
struct ChatAttachmentPreviewSheet: View {
    let attachment: ChatAttachment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(attachment.displayName).bold()
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
            Divider()
            content
        }
        .frame(width: 600, height: 700)
    }

    @ViewBuilder
    private var content: some View {
        switch attachment.kind {
        case .image:
            AsyncImage(url: attachment.url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFit()
                case .empty:
                    ProgressView()
                case .failure:
                    Text("Failed to load image").foregroundStyle(.secondary)
                @unknown default:
                    EmptyView()
                }
            }
            .padding()
        case .pdf:
            PDFPreview(url: attachment.url)
        case .code, .text:
            if let s = try? String(contentsOf: attachment.url, encoding: .utf8) {
                ScrollView {
                    Text(s)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                }
            } else {
                Text("Cannot read file").foregroundStyle(.secondary)
            }
        case .other:
            Text("No preview available").foregroundStyle(.secondary)
        }
    }
}

/// `NSViewRepresentable` wrapper around `PDFView` so we can render
/// PDFs without leaving SwiftUI. `autoScales` keeps the document
/// fitted to the sheet at any window size.
private struct PDFPreview: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = PDFDocument(url: url)
        view.autoScales = true
        return view
    }
    func updateNSView(_ nsView: PDFView, context: Context) {}
}
