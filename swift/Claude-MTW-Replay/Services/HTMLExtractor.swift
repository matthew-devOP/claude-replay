import Foundation
import Compression

// MARK: - Extraction result

struct ExtractedData {
    let turns: [Turn]
    let bookmarks: [Bookmark]
}

// MARK: - HTMLExtractor

enum HTMLExtractor {

    /// Extract turns and bookmarks from a generated HTML replay string.
    static func extractData(html: String) throws -> ExtractedData {
        let blobs = findBlobs(html)

        guard blobs.count >= 2 else {
            throw ExtractionError.missingBlobs(found: blobs.count)
        }

        let turnsData = try decodeBlob(blobs[0], as: [Turn].self)
        let bookmarksData = try decodeBlob(blobs[1], as: [Bookmark].self)

        return ExtractedData(turns: turnsData, bookmarks: bookmarksData)
    }

    // MARK: - Errors

    enum ExtractionError: LocalizedError {
        case missingBlobs(found: Int)
        case decodeFailed(String)
        case decompressFailed

        var errorDescription: String? {
            switch self {
            case .missingBlobs(let n):
                return "Could not find data blobs in HTML (expected at least 2 decodeData calls, found \(n))"
            case .decodeFailed(let msg):
                return "Failed to decode data blob: \(msg)"
            case .decompressFailed:
                return "Failed to decompress data blob"
            }
        }
    }

    // MARK: - Find blobs

    /// Find all data blobs passed to the async decode function.
    /// Works with both minified and unminified output.
    /// Returns blobs in source order: [turnsBlob, bookmarksBlob].
    static func findBlobs(_ html: String) -> [String] {
        var blobs: [String] = []
        // Pattern: await <identifier>("
        let pattern = try! NSRegularExpression(pattern: #"await\s+[\w$]+\(""#)
        let nsHtml = html as NSString
        let matches = pattern.matches(in: html, range: NSRange(location: 0, length: nsHtml.length))

        for match in matches {
            let start = match.range.location + match.range.length
            var i = start
            while i < nsHtml.length {
                let ch = nsHtml.character(at: i)
                // backslash: skip escaped character
                if ch == UInt16(UInt8(ascii: "\\")) {
                    i += 2
                    continue
                }
                // closing unescaped ") — end of blob
                if ch == UInt16(UInt8(ascii: "\"")) &&
                   i + 1 < nsHtml.length &&
                   nsHtml.character(at: i + 1) == UInt16(UInt8(ascii: ")")) {
                    let blobRange = NSRange(location: start, length: i - start)
                    blobs.append(nsHtml.substring(with: blobRange))
                    break
                }
                i += 1
            }
        }

        return blobs
    }

    // MARK: - Decode blob

    /// Decode a data blob -- either raw JSON (unescaped) or base64-encoded deflate.
    static func decodeBlob<T: Decodable>(_ raw: String, as type: T.Type) throws -> T {
        let jsonString: String

        if raw.hasPrefix("[") || raw.hasPrefix("{") || raw.hasPrefix("\\") {
            // Raw JSON (--no-compress mode) -- undo JS string literal escaping.
            jsonString = unescapeJsonString(raw)
        } else {
            // Compressed: base64-encoded deflate
            guard let compressedData = Data(base64Encoded: raw) else {
                throw ExtractionError.decodeFailed("Invalid base64")
            }
            guard let decompressed = inflate(compressedData) else {
                throw ExtractionError.decompressFailed
            }
            guard let str = String(data: decompressed, encoding: .utf8) else {
                throw ExtractionError.decodeFailed("Invalid UTF-8 after decompression")
            }
            jsonString = str
        }

        guard let data = jsonString.data(using: .utf8) else {
            throw ExtractionError.decodeFailed("Could not encode to UTF-8")
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw ExtractionError.decodeFailed(error.localizedDescription)
        }
    }

    // MARK: - Private helpers

    /// Undo JS string literal escaping applied by escapeJsonForScript.
    private static func unescapeJsonString(_ raw: String) -> String {
        var json = ""
        json.reserveCapacity(raw.count)
        var i = raw.startIndex
        while i < raw.endIndex {
            let ch = raw[i]
            if ch == "\\" {
                let next = raw.index(after: i)
                if next < raw.endIndex {
                    let nc = raw[next]
                    switch nc {
                    case "\\": json.append("\\"); i = raw.index(after: next); continue
                    case "\"": json.append("\""); i = raw.index(after: next); continue
                    case "n":  json.append("\n"); i = raw.index(after: next); continue
                    case "r":  json.append("\r"); i = raw.index(after: next); continue
                    default:   json.append(ch)
                    }
                } else {
                    json.append(ch)
                }
            } else {
                json.append(ch)
            }
            i = raw.index(after: i)
        }
        // Undo HTML-in-script escapes
        json = json.replacingOccurrences(of: "<\\/", with: "</")
        json = json.replacingOccurrences(of: "<\\!--", with: "<!--")
        return json
    }

    /// Decompress raw deflate or zlib-wrapped data.
    /// Handles both raw deflate (from Node.js) and zlib-wrapped (from Apple COMPRESSION_ZLIB).
    private static func inflate(_ data: Data) -> Data? {
        // Try as-is first (handles zlib-wrapped data)
        if let result = inflateRaw(data), result.count > 0 {
            return result
        }
        // If data is raw deflate (no zlib header), prepend zlib header for Apple's decompressor
        if data.count > 0, data[0] != 0x78 {
            var wrapped = Data([0x78, 0x9C]) // zlib header: default compression
            wrapped.append(data)
            // Append dummy Adler-32 checksum (decompressor may ignore it)
            wrapped.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
            if let result = inflateRaw(wrapped), result.count > 0 {
                return result
            }
        }
        return nil
    }

    private static func inflateRaw(_ data: Data) -> Data? {
        let sourceBytes = [UInt8](data)
        let destinationSize = max(sourceBytes.count * 10, 65536)
        var destinationBuffer = [UInt8](repeating: 0, count: destinationSize)

        let decodedSize = compression_decode_buffer(
            &destinationBuffer, destinationSize,
            sourceBytes, sourceBytes.count,
            nil, COMPRESSION_ZLIB
        )

        guard decodedSize > 0 else { return nil }
        // If buffer was full, retry with larger buffer
        if decodedSize == destinationSize {
            let largerSize = sourceBytes.count * 50
            var largerBuffer = [UInt8](repeating: 0, count: largerSize)
            let retrySize = compression_decode_buffer(
                &largerBuffer, largerSize,
                sourceBytes, sourceBytes.count,
                nil, COMPRESSION_ZLIB
            )
            guard retrySize > 0 else { return nil }
            return Data(largerBuffer.prefix(retrySize))
        }
        return Data(destinationBuffer.prefix(decodedSize))
    }
}
