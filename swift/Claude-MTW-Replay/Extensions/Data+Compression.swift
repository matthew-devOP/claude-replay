import Foundation
import Compression

extension Data {
    func deflateCompressed() throws -> Data {
        let sourceSize = count
        guard sourceSize > 0 else { return Data() }
        let destSize = sourceSize + 512
        let destBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: destSize)
        defer { destBuf.deallocate() }
        let compressed = withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Int in
            guard let srcPtr = src.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
            return compression_encode_buffer(destBuf, destSize, srcPtr, sourceSize, nil, COMPRESSION_ZLIB)
        }
        guard compressed > 0 else { throw CompressionError.compressionFailed }
        return Data(bytes: destBuf, count: compressed)
    }

    func deflateDecompressed() throws -> Data {
        let sourceSize = count
        guard sourceSize > 0 else { return Data() }
        var destSize = sourceSize * 8
        var destBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: destSize)
        var result = withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Int in
            guard let srcPtr = src.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
            return compression_decode_buffer(destBuf, destSize, srcPtr, sourceSize, nil, COMPRESSION_ZLIB)
        }
        if result == 0 || result == destSize {
            destBuf.deallocate()
            destSize = sourceSize * 32
            destBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: destSize)
            result = withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Int in
                guard let srcPtr = src.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                return compression_decode_buffer(destBuf, destSize, srcPtr, sourceSize, nil, COMPRESSION_ZLIB)
            }
        }
        guard result > 0 else { destBuf.deallocate(); throw CompressionError.decompressionFailed }
        let data = Data(bytes: destBuf, count: result)
        destBuf.deallocate()
        return data
    }

    func base64EncodedStringForEmbed() throws -> String {
        try deflateCompressed().base64EncodedString()
    }
}

extension String {
    func compressedBase64() throws -> String {
        guard let data = data(using: .utf8) else { throw CompressionError.invalidInput }
        return try data.base64EncodedStringForEmbed()
    }
}

enum CompressionError: LocalizedError {
    case compressionFailed, decompressionFailed, invalidInput
    var errorDescription: String? {
        switch self {
        case .compressionFailed: return "Failed to compress data."
        case .decompressionFailed: return "Failed to decompress data."
        case .invalidInput: return "Invalid input for compression."
        }
    }
}
