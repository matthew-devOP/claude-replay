import Foundation
import Compression

// MARK: - Data types used for rendering

/// Represents a tool call within an assistant block.
struct ToolCall: Codable {
    let name: String
    let input: [String: AnyCodable]
    var result: String?
    var isError: Bool?
    var resultTimestamp: String?

    enum CodingKeys: String, CodingKey {
        case name, input, result
        case isError = "is_error"
        case resultTimestamp
    }
}

/// A single assistant block (text, thinking, or tool_use).
struct AssistantBlock: Codable {
    let kind: String          // "text", "thinking", "tool_use"
    var text: String
    var timestamp: String?
    var toolCall: ToolCall?

    enum CodingKeys: String, CodingKey {
        case kind, text, timestamp
        case toolCall = "tool_call"
    }
}

/// A single turn in the conversation.
struct Turn: Codable {
    let index: Int
    var userText: String
    var blocks: [AssistantBlock]
    var timestamp: String?
    var systemEvents: [String]?

    enum CodingKeys: String, CodingKey {
        case index
        case userText = "user_text"
        case blocks, timestamp
        case systemEvents = "system_events"
    }
}

/// A bookmark for a specific turn.
struct Bookmark: Codable {
    let turnIndex: Int
    let label: String
}

/// A type-erased Codable wrapper for heterogeneous JSON values.
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let b = try? container.decode(Bool.self) {
            value = b
        } else if let i = try? container.decode(Int.self) {
            value = i
        } else if let d = try? container.decode(Double.self) {
            value = d
        } else if let s = try? container.decode(String.self) {
            value = s
        } else if let arr = try? container.decode([AnyCodable].self) {
            value = arr.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let b as Bool:
            try container.encode(b)
        case let i as Int:
            try container.encode(i)
        case let d as Double:
            try container.encode(d)
        case let s as String:
            try container.encode(s)
        case let arr as [Any]:
            try container.encode(arr.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Render options

struct RenderOptions {
    var speed: Double = 1.0
    var showThinking: Bool = true
    var showToolCalls: Bool = true
    var themeCss: String = ""
    var themeBg: String = "#1a1b26"
    var userLabel: String = "User"
    var assistantLabel: String = "Claude"
    var title: String = "Claude Code Replay"
    var description: String = "Interactive AI session replay"
    var ogImage: String = "https://es617.github.io/claude-replay/og.png"
    var compress: Bool = true
    var bookmarks: [Bookmark] = []
}

// MARK: - HTMLRenderer

enum HTMLRenderer {

    // MARK: Public

    /// Render turns into a self-contained HTML string.
    static func render(turns: [Turn], options: RenderOptions = RenderOptions()) -> String {
        let speed = max(0.1, min(options.speed.isFinite ? options.speed : 1.0, 10))

        guard var html = loadTemplate() else {
            return "<!-- ERROR: could not load player.html template -->"
        }

        // Replace simple placeholders first (before injecting data blobs which
        // may contain text matching the placeholder patterns).
        html = html.replacingOccurrences(of: "/*THEME_CSS*/", with: options.themeCss)
        html = html.replacingOccurrences(of: "/*THEME_BG*/", with: escapeHtml(options.themeBg))

        // Speed: first occurrence with trailing "1" is the JS default value assignment
        if let range = html.range(of: "/*INITIAL_SPEED*/1") {
            html = html.replacingCharacters(in: range, with: String(speed))
        }
        html = html.replacingOccurrences(of: "/*INITIAL_SPEED*/", with: String(speed))

        html = html.replacingOccurrences(of: "/*CHECKED_THINKING*/", with: options.showThinking ? "checked" : "")
        html = html.replacingOccurrences(of: "/*CHECKED_TOOLS*/", with: options.showToolCalls ? "checked" : "")
        html = html.replacingOccurrences(of: "/*PAGE_TITLE*/", with: escapeHtml(options.title))
        html = html.replacingOccurrences(of: "/*PAGE_DESCRIPTION*/", with: escapeHtml(options.description))
        html = html.replacingOccurrences(of: "/*OG_IMAGE*/", with: escapeHtml(options.ogImage))
        html = html.replacingOccurrences(of: "/*USER_LABEL*/", with: escapeHtml(options.userLabel))
        html = html.replacingOccurrences(of: "/*ASSISTANT_LABEL*/", with: escapeHtml(options.assistantLabel))

        // Data blobs last. BOOKMARKS before TURNS.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let bookmarksJson = (try? encoder.encode(options.bookmarks))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let turnsData = turnsToJsonData(turns)
        let turnsJson = (try? encoder.encode(turnsData))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        let embedData: (String) -> String = options.compress ? compressForEmbed : escapeJsonForScript

        // Use single replacement to avoid $-pattern issues
        if let range = html.range(of: "/*BOOKMARKS_DATA*/") {
            html = html.replacingCharacters(in: range, with: embedData(bookmarksJson))
        }
        if let range = html.range(of: "/*TURNS_DATA*/") {
            html = html.replacingCharacters(in: range, with: embedData(turnsJson))
        }

        return html
    }

    // MARK: Internal helpers

    /// Escape text for safe embedding in HTML text nodes and attribute values.
    static func escapeHtml(_ str: String) -> String {
        str.replacingOccurrences(of: "&", with: "&amp;")
           .replacingOccurrences(of: "<", with: "&lt;")
           .replacingOccurrences(of: ">", with: "&gt;")
           .replacingOccurrences(of: "\"", with: "&quot;")
           .replacingOccurrences(of: "'", with: "&#39;")
    }

    /// Escape a JSON string for safe embedding inside a double-quoted JS string literal in a <script> tag.
    static func escapeJsonForScript(_ json: String) -> String {
        json.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "</", with: "<\\/")
            .replacingOccurrences(of: "<!--", with: "<\\!--")
    }

    /// Compress a JSON string to base64-encoded deflate for embedding.
    static func compressForEmbed(_ json: String) -> String {
        guard let sourceData = json.data(using: .utf8) else { return "" }
        let sourceBytes = [UInt8](sourceData)
        let destinationSize = sourceBytes.count + 512
        var destinationBuffer = [UInt8](repeating: 0, count: destinationSize)

        let compressedSize = compression_encode_buffer(
            &destinationBuffer, destinationSize,
            sourceBytes, sourceBytes.count,
            nil, COMPRESSION_ZLIB
        )

        guard compressedSize > 0 else { return "" }
        let compressedData = Data(destinationBuffer.prefix(compressedSize))
        return compressedData.base64EncodedString()
    }

    /// Prepare turns for serialization (mirrors turnsToJsonData in renderer.mjs).
    static func turnsToJsonData(_ turns: [Turn]) -> [Turn] {
        // In Swift we return turns as-is (redaction can be added later).
        // The Turn struct is already Codable and matches the expected JSON shape.
        turns
    }

    // MARK: Private

    /// Load the HTML template from the app bundle.
    private static func loadTemplate() -> String? {
        // Try minified first, fall back to unminified
        if let url = Bundle.main.url(forResource: "player.min", withExtension: "html"),
           let contents = try? String(contentsOf: url, encoding: .utf8) {
            return contents
        }
        if let url = Bundle.main.url(forResource: "player", withExtension: "html"),
           let contents = try? String(contentsOf: url, encoding: .utf8) {
            return contents
        }
        return nil
    }
}
