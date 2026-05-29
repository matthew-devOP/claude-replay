import Foundation
import Compression

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
    var redactSecrets: Bool = true
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
        let turnsData = turnsToJsonData(turns, redact: options.redactSecrets)
        let turnsJson = (try? JSONSerialization.data(withJSONObject: turnsData, options: [.sortedKeys]))
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

    /// Compress a JSON string to base64-encoded raw deflate for embedding.
    /// Produces raw deflate (RFC 1951) to match Node.js zlib.deflateSync().
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
        var compressedData = Data(destinationBuffer.prefix(compressedSize))
        // Strip zlib wrapper to get raw deflate: remove 2-byte header and 4-byte Adler-32 checksum
        if compressedData.count > 6, compressedData[0] == 0x78 {
            compressedData = compressedData.dropFirst(2).dropLast(4)
        }
        return compressedData.base64EncodedString()
    }

    /// Prepare turns for serialization as plain dictionaries (mirrors turnsToJsonData in renderer.mjs).
    /// Strips internal-only fields (id, toolUseId) and only includes is_error when true.
    /// When redact is true, applies secret redaction to all string content including tool_call input.
    static func turnsToJsonData(_ turns: [Turn], redact: Bool = false) -> [[String: Any]] {
        let redactStr: (String) -> String = redact ? SecretRedactor.redactSecrets : { $0 }

        return turns.map { turn in
            var dict: [String: Any] = [
                "index": turn.index,
                "user_text": redactStr(turn.userText),
            ]
            if let ts = turn.timestamp {
                dict["timestamp"] = ts
            }
            if let events = turn.systemEvents {
                dict["system_events"] = events.map { redactStr($0) }
            }

            dict["blocks"] = turn.blocks.map { block -> [String: Any] in
                var bDict: [String: Any] = [
                    "kind": block.kind.rawValue,
                    "text": redactStr(block.text),
                ]
                if let ts = block.timestamp {
                    bDict["timestamp"] = ts
                }
                if let tc = block.toolCall {
                    var tcDict: [String: Any] = [
                        "name": tc.name,
                    ]
                    // Redact input values recursively
                    if redact {
                        var redactedInput: [String: Any] = [:]
                        for (key, val) in tc.input {
                            redactedInput[key] = SecretRedactor.redactObject(val.value)
                        }
                        tcDict["input"] = redactedInput
                    } else {
                        tcDict["input"] = tc.input.mapValues { $0.value }
                    }
                    if let result = tc.result {
                        tcDict["result"] = redactStr(result)
                    }
                    if let rts = tc.resultTimestamp {
                        // Web format uses camelCase for this key inside tool_call
                        // (src/parser.mjs ToolCall typedef; player.html:1149 reads
                        // tool_call.resultTimestamp). The surrounding block keys are
                        // snake_case, but this one is not — match the web exactly so
                        // tool-result timing survives export and extract round-trips.
                        tcDict["resultTimestamp"] = rts
                    }
                    if tc.isError {
                        tcDict["is_error"] = true
                    }
                    bDict["tool_call"] = tcDict
                }
                return bDict
            }

            return dict
        }
    }

    // MARK: Private

    /// Load the HTML template from the app bundle.
    private static func loadTemplate() -> String? {
        // Search in Bundle.main first (app runtime), then in the bundle that contains
        // this class (test target loaded the host app via TEST_HOST, so resources can
        // be discovered via either bundle depending on the run context).
        let bundles: [Bundle] = [Bundle.main, Bundle(for: BundleToken.self)]
        for bundle in bundles {
            if let url = bundle.url(forResource: "player.min", withExtension: "html"),
               let contents = try? String(contentsOf: url, encoding: .utf8) {
                return contents
            }
            if let url = bundle.url(forResource: "player", withExtension: "html"),
               let contents = try? String(contentsOf: url, encoding: .utf8) {
                return contents
            }
        }
        return nil
    }

    private final class BundleToken {}
}
