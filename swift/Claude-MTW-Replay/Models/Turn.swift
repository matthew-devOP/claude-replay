import Foundation

// MARK: - AnyCodable

/// Type-erased Codable wrapper for heterogeneous JSON values.
struct AnyCodable: Codable, Hashable, Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON type"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let lData = try? encoder.encode(lhs),
              let rData = try? encoder.encode(rhs) else { return false }
        return lData == rData
    }

    func hash(into hasher: inout Hasher) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        if let data = try? encoder.encode(self) {
            hasher.combine(data)
        }
    }

    // MARK: - Convenience accessors

    var stringValue: String? { value as? String }
    var intValue: Int? { value as? Int }
    var doubleValue: Double? { value as? Double }
    var boolValue: Bool? { value as? Bool }
    var arrayValue: [Any]? { value as? [Any] }
    var dictValue: [String: Any]? { value as? [String: Any] }
}

// MARK: - BlockKind

enum BlockKind: String, Codable, Hashable, Sendable {
    case text
    case thinking
    case toolUse = "tool_use"
}

// MARK: - ToolCall

struct ToolCall: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let toolUseId: String
    let name: String
    let input: [String: AnyCodable]
    var result: String?
    var resultTimestamp: String?
    var isError: Bool

    init(
        id: UUID = UUID(),
        toolUseId: String,
        name: String,
        input: [String: AnyCodable],
        result: String? = nil,
        resultTimestamp: String? = nil,
        isError: Bool = false
    ) {
        self.id = id
        self.toolUseId = toolUseId
        self.name = name
        self.input = input
        self.result = result
        self.resultTimestamp = resultTimestamp
        self.isError = isError
    }

    enum CodingKeys: String, CodingKey {
        case id
        case toolUseId = "tool_use_id"
        case name
        case input
        case result
        case resultTimestamp
        case isError = "is_error"
    }
}

// MARK: - AssistantBlock

struct AssistantBlock: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var kind: BlockKind
    var text: String
    var toolCall: ToolCall?
    var timestamp: String?

    init(
        id: UUID = UUID(),
        kind: BlockKind,
        text: String,
        toolCall: ToolCall? = nil,
        timestamp: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.toolCall = toolCall
        self.timestamp = timestamp
    }

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case text
        case toolCall = "tool_call"
        case timestamp
    }
}

// MARK: - Turn

struct Turn: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var index: Int
    var userText: String
    var blocks: [AssistantBlock]
    var timestamp: String?
    var systemEvents: [String]?

    init(
        id: UUID = UUID(),
        index: Int,
        userText: String,
        blocks: [AssistantBlock],
        timestamp: String? = nil,
        systemEvents: [String]? = nil
    ) {
        self.id = id
        self.index = index
        self.userText = userText
        self.blocks = blocks
        self.timestamp = timestamp
        self.systemEvents = systemEvents
    }

    enum CodingKeys: String, CodingKey {
        case id
        case index
        case userText = "user_text"
        case blocks
        case timestamp
        case systemEvents = "system_events"
    }
}
