import Foundation
import UniformTypeIdentifiers

/// G9/G10 — represents a single file the user has staged on the chat
/// input bar via drag-drop (or, eventually, a file picker). The chat
/// view-model holds a list of these in `pendingAttachments`; on
/// `send()` they are folded into the outbound message (code/text inline
/// as fenced blocks, images/PDFs as base64 content blocks via the sidecar).
///
/// The `kind` is decided purely from the file extension because we
/// don't want to read the file just to classify it; the preview sheet
/// re-checks at render time anyway.
struct ChatAttachment: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let displayName: String
    let kind: Kind

    enum Kind: Equatable {
        case image
        case pdf
        case code(language: String?)
        case text
        case other
    }

    static func from(url: URL) -> ChatAttachment {
        let displayName = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let kind: Kind
        switch ext {
        case "png", "jpg", "jpeg", "gif", "webp", "heic":
            kind = .image
        case "pdf":
            kind = .pdf
        case "swift", "js", "ts", "py", "rs", "go", "rb", "java",
             "cpp", "c", "h", "sh", "json", "yaml", "yml", "toml",
             "xml", "html", "css", "md":
            kind = .code(language: ext)
        case "txt", "log":
            kind = .text
        default:
            kind = .other
        }
        return ChatAttachment(url: url, displayName: displayName, kind: kind)
    }

    /// Whether this attachment is sent to the sidecar as a binary content
    /// block (image/PDF) rather than inlined into the prompt text.
    var isBinary: Bool {
        switch kind {
        case .image, .pdf: return true
        case .code, .text, .other: return false
        }
    }

    /// The kind string the sidecar protocol understands ("image" | "pdf"
    /// | "file"). Only meaningful for binary attachments.
    var outboundKind: String {
        switch kind {
        case .image: return "image"
        case .pdf: return "pdf"
        default: return "file"
        }
    }

    /// MIME type derived from the extension. Anthropic accepts png/jpeg/gif/
    /// webp as inline images and application/pdf as documents; the sidecar
    /// validates and gracefully degrades anything it can't inline.
    var mediaType: String {
        switch url.pathExtension.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "heic": return "image/heic"
        case "pdf": return "application/pdf"
        default: return "application/octet-stream"
        }
    }
}
