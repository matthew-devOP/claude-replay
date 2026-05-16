import Foundation

// MARK: - FilterOptions

struct FilterOptions {
    var turnRange: (Int, Int)?
    var excludeTurns: Set<Int>?
    var timeFrom: String?
    var timeTo: String?
}

// MARK: - TranscriptParser

/// Port of parser.mjs — parses Claude Code, Cursor, and Codex CLI JSONL transcripts
/// into structured Turn arrays.
enum TranscriptParser {

    // MARK: - 1. cleanSystemTags

    /// Strip XML system tags from user message text, keeping only meaningful content.
    static func cleanSystemTags(_ text: String) -> String {
        var t = text

        // Replace <task-notification> blocks with compact marker
        t = t.replacingOccurrences(
            of: #"<task-notification>\s*<task-id>[^<]*</task-id>\s*<output-file>[^<]*</output-file>\s*<status>([^<]*)</status>\s*<summary>([^<]*)</summary>\s*</task-notification>"#,
            with: "[bg-task: $2]",
            options: .regularExpression
        )
        // Remove trailing "Read the output file..." lines
        t = t.replacingOccurrences(
            of: #"\n*Read the output file to retrieve the result:[^\n]*"#,
            with: "",
            options: .regularExpression
        )
        // Unwrap Cursor's <user_query> tags
        t = replaceCapture(in: t, pattern: #"<user_query>([\s\S]*?)</user_query>\s*"#) { match, groups in
            groups[0].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Remove <system-reminder> blocks
        t = t.replacingOccurrences(of: #"<system-reminder>[\s\S]*?</system-reminder>\s*"#, with: "", options: .regularExpression)
        // Remove IDE context tags
        t = t.replacingOccurrences(of: #"<ide_opened_file>[\s\S]*?</ide_opened_file>\s*"#, with: "", options: .regularExpression)
        // Remove local-command-caveat
        t = t.replacingOccurrences(of: #"<local-command-caveat>[\s\S]*?</local-command-caveat>\s*"#, with: "", options: .regularExpression)
        // Extract slash command name
        t = replaceCapture(in: t, pattern: #"<command-name>([\s\S]*?)</command-name>\s*"#) { _, groups in
            groups[0].trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
        }
        // Remove command-message and empty command-args
        t = t.replacingOccurrences(of: #"<command-message>[\s\S]*?</command-message>\s*"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"<command-args>\s*</command-args>\s*"#, with: "", options: .regularExpression)
        // Keep non-empty command args
        t = replaceCapture(in: t, pattern: #"<command-args>([\s\S]*?)</command-args>\s*"#) { _, groups in
            let trimmed = groups[0].trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "" : trimmed + "\n"
        }
        // Remove local-command-stdout
        t = t.replacingOccurrences(of: #"<local-command-stdout>[\s\S]*?</local-command-stdout>\s*"#, with: "", options: .regularExpression)

        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 2. extractText

    /// Handle string and array content, extracting plain text from user messages.
    static func extractText(_ content: Any?) -> String {
        if let str = content as? String {
            return cleanSystemTags(str)
        }
        if let blocks = content as? [[String: Any]] {
            var parts: [String] = []
            for block in blocks {
                if block["type"] as? String == "text",
                   let text = block["text"] as? String {
                    parts.append(text)
                }
            }
            return cleanSystemTags(parts.joined(separator: "\n"))
        }
        return ""
    }

    // MARK: - 3. detectFormat

    /// Peek at the first JSON line to determine transcript format.
    static func detectFormat(filePath: String) -> TranscriptFormat {
        guard let text = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return .unknown
        }
        return detectFormatFromText(text)
    }

    static func detectFormatFromText(_ text: String) -> TranscriptFormat {
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            guard let data = trimmed.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            let type = obj["type"] as? String
            if type == "session_meta" { return .codex }
            if type == "user" || type == "assistant" { return .claudeCode }
            let role = obj["role"] as? String
            if role == "user" || role == "assistant" { return .cursor }
        }
        return .unknown
    }

    // MARK: - 4. parseJsonl

    /// Line-by-line JSONL parsing. Returns entries normalized to Claude Code shape + format.
    static func parseJsonl(_ text: String) -> (entries: [[String: Any]], format: TranscriptFormat) {
        var entries: [[String: Any]] = []
        var format: TranscriptFormat = .unknown

        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            guard let data = trimmed.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            let topType = obj["type"] as? String
            if topType == "user" || topType == "assistant" {
                if format == .unknown { format = .claudeCode }
                entries.append(obj)
            } else if topType == nil {
                // Cursor format: { role, message: { content } }
                let msg = obj["message"] as? [String: Any]
                let role = msg?["role"] as? String ?? obj["role"] as? String
                if role == "user" || role == "assistant" {
                    if format == .unknown { format = .cursor }
                    let content = msg?["content"] ?? ""
                    let ts = obj["timestamp"] as? String
                    let normalized: [String: Any] = [
                        "type": role!,
                        "message": ["role": role!, "content": content],
                        "timestamp": ts as Any
                    ]
                    entries.append(normalized)
                }
            }
        }
        return (entries, format)
    }

    // MARK: - 5. collectAssistantBlocks

    /// Scan consecutive assistant entries starting at `start`, deduplicating blocks.
    /// Returns (blocks, nextIndex).
    static func collectAssistantBlocks(_ entries: [[String: Any]], start: Int) -> ([AssistantBlock], Int) {
        var blocks: [AssistantBlock] = []
        var seenKeys = Set<String>()
        var i = start

        while i < entries.count {
            let entry = entries[i]
            let role = entryRole(entry)
            if role != "assistant" { break }

            let entryTs = entry["timestamp"] as? String
            let message = entry["message"] as? [String: Any]
            let content = message?["content"]

            if let contentArray = content as? [[String: Any]] {
                for block in contentArray {
                    let btype = block["type"] as? String ?? ""

                    if btype == "text" {
                        let text = (block["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if text.isEmpty || text == "No response requested." { continue }
                        let key = "text:\(text)"
                        if seenKeys.contains(key) { continue }
                        seenKeys.insert(key)
                        blocks.append(AssistantBlock(kind: .text, text: text, toolCall: nil, timestamp: entryTs))
                    } else if btype == "thinking" {
                        let text = (block["thinking"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if text.isEmpty { continue }
                        let key = "thinking:\(text)"
                        if seenKeys.contains(key) { continue }
                        seenKeys.insert(key)
                        blocks.append(AssistantBlock(kind: .thinking, text: text, toolCall: nil, timestamp: entryTs))
                    } else if btype == "tool_use" {
                        let toolId = block["id"] as? String ?? ""
                        let key = "tool_use:\(toolId)"
                        if seenKeys.contains(key) { continue }
                        seenKeys.insert(key)
                        let inputDict = (block["input"] as? [String: Any]) ?? [:]
                        let tc = ToolCall(
                            toolUseId: toolId,
                            name: block["name"] as? String ?? "",
                            input: inputDict.mapValues { AnyCodable($0) },
                            result: nil,
                            resultTimestamp: nil,
                            isError: false
                        )
                        blocks.append(AssistantBlock(kind: .toolUse, text: "", toolCall: tc, timestamp: entryTs))
                    }
                }
            }
            i += 1
        }

        return (blocks, i)
    }

    // MARK: - 6. attachToolResults

    /// Match tool_result blocks from user entries to tool_use blocks by tool_use_id.
    /// Returns index after consumed entries.
    static func attachToolResults(_ blocks: inout [AssistantBlock], entries: [[String: Any]], resultStart: Int) -> Int {
        // Build pending map: tool_use_id → index in blocks array
        var pending: [String: Int] = [:]
        for (idx, b) in blocks.enumerated() {
            if b.kind == .toolUse, let tc = b.toolCall {
                pending[tc.toolUseId] = idx
            }
        }
        if pending.isEmpty { return resultStart }

        var i = resultStart
        while i < entries.count && !pending.isEmpty {
            let entry = entries[i]
            let role = entryRole(entry)
            if role == "assistant" { break }
            if role == "user" {
                let message = entry["message"] as? [String: Any]
                let content = message?["content"]
                if let contentArray = content as? [[String: Any]] {
                    var hasToolResult = false
                    for block in contentArray {
                        if block["type"] as? String == "tool_result" {
                            hasToolResult = true
                            let tid = block["tool_use_id"] as? String ?? ""
                            if let blockIdx = pending[tid] {
                                let resultContent = block["content"]
                                var resultText: String
                                if let arr = resultContent as? [[String: Any]] {
                                    resultText = arr
                                        .filter { $0["type"] as? String == "text" }
                                        .compactMap { $0["text"] as? String }
                                        .joined(separator: "\n")
                                } else if let str = resultContent as? String {
                                    resultText = str
                                } else {
                                    resultText = String(describing: resultContent ?? "")
                                }
                                // Strip <tool_use_error> wrapper
                                if let range = resultText.range(of: #"^<tool_use_error>([\s\S]*)</tool_use_error>$"#, options: .regularExpression) {
                                    resultText = String(resultText[range])
                                    resultText = replaceCapture(in: resultText, pattern: #"^<tool_use_error>([\s\S]*)</tool_use_error>$"#) { _, groups in
                                        groups[0]
                                    }
                                }
                                blocks[blockIdx].toolCall?.result = resultText
                                blocks[blockIdx].toolCall?.resultTimestamp = entry["timestamp"] as? String
                                blocks[blockIdx].toolCall?.isError = block["is_error"] as? Bool ?? false
                                pending.removeValue(forKey: tid)
                            }
                        }
                    }
                    if !hasToolResult { break }
                } else {
                    break
                }
            }
            i += 1
        }

        return i
    }

    // MARK: - 7. parseCodexPatch

    /// Parse a `*** Begin Patch` format string into file path and content info.
    static func parseCodexPatch(_ patchStr: String) -> [String: Any] {
        var lines = patchStr.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        // Remove trailing empty lines
        while !lines.isEmpty && lines.last == "" { lines.removeLast() }

        var filePath = ""
        var isNew = false
        var oldLines: [String] = []
        var newLines: [String] = []

        for line in lines {
            if line.hasPrefix("*** Begin Patch") || line.hasPrefix("*** End Patch") { continue }
            if line.hasPrefix("*** Add File:") {
                filePath = line.replacingOccurrences(of: "*** Add File:", with: "").trimmingCharacters(in: .whitespaces)
                isNew = true
                continue
            }
            if line.hasPrefix("*** Update File:") {
                filePath = line.replacingOccurrences(of: "*** Update File:", with: "").trimmingCharacters(in: .whitespaces)
                isNew = false
                continue
            }
            if line.hasPrefix("@@") { continue }
            if line.hasPrefix("+") {
                newLines.append(String(line.dropFirst()))
            } else if line.hasPrefix("-") {
                oldLines.append(String(line.dropFirst()))
            } else {
                oldLines.append(line)
                newLines.append(line)
            }
        }

        if isNew {
            return ["file_path": filePath, "content": newLines.joined(separator: "\n"), "isNew": true]
        }
        return [
            "file_path": filePath,
            "old_string": oldLines.joined(separator: "\n"),
            "new_string": newLines.joined(separator: "\n"),
            "isNew": false
        ]
    }

    // MARK: - 8. extractCodexUserText

    /// Extract the actual user request from Codex user messages, stripping IDE boilerplate.
    static func extractCodexUserText(_ text: String) -> String {
        let marker = "## My request for Codex:"
        if let range = text.range(of: marker) {
            return String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let marker2 = "## My request for Codex"
        if let range = text.range(of: marker2) {
            var after = String(text[range.upperBound...])
            // Skip optional colon and whitespace
            if after.hasPrefix(":") { after = String(after.dropFirst()) }
            return after.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 9. parseCodexTranscript

    /// Parse a Codex CLI event-based JSONL transcript into Turn[].
    static func parseCodexTranscript(_ text: String) -> [Turn] {
        var events: [[String: Any]] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            guard let data = trimmed.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            events.append(obj)
        }

        var turns: [Turn] = []
        var turnIndex = 0
        var currentUserText = ""
        var currentTimestamp = ""
        var currentBlocks: [AssistantBlock] = []
        var pendingCalls: [String: Int] = [:]  // callId → index in currentBlocks
        var inTurn = false

        for evt in events {
            let type = evt["type"] as? String ?? ""
            let payload = evt["payload"] as? [String: Any] ?? [:]
            let ts = evt["timestamp"] as? String

            let payloadType = payload["type"] as? String ?? ""

            if type == "event_msg" && payloadType == "task_started" {
                inTurn = true
                currentUserText = ""
                currentTimestamp = ts ?? ""
                currentBlocks = []
                pendingCalls = [:]
                continue
            }

            if type == "event_msg" && payloadType == "task_complete" {
                if inTurn {
                    turnIndex += 1
                    turns.append(Turn(
                        index: turnIndex,
                        userText: currentUserText,
                        blocks: currentBlocks,
                        timestamp: currentTimestamp
                    ))
                }
                inTurn = false
                continue
            }

            if !inTurn { continue }

            if type == "event_msg" && payloadType == "user_message" {
                let msg = payload["message"] as? String ?? ""
                currentUserText = extractCodexUserText(msg)
                if let t = ts { currentTimestamp = t }
                continue
            }

            if type == "response_item" {
                let ptype = payload["type"] as? String ?? ""
                let role = payload["role"] as? String ?? ""
                let phase = payload["phase"] as? String ?? ""

                // User message as response_item
                if ptype == "message" && role == "user" {
                    if let content = payload["content"] as? [[String: Any]] {
                        let textParts = content
                            .filter { $0["type"] as? String == "input_text" }
                            .compactMap { $0["text"] as? String }
                        let raw = textParts.joined(separator: "\n")
                        let extracted = extractCodexUserText(raw)
                        if !extracted.isEmpty && currentUserText.isEmpty {
                            currentUserText = extracted
                        }
                    }
                    continue
                }

                // Skip developer messages
                if ptype == "message" && role == "developer" { continue }

                // Assistant text
                if ptype == "message" && role == "assistant" {
                    if let content = payload["content"] as? [[String: Any]] {
                        let textParts = content
                            .filter { $0["type"] as? String == "output_text" }
                            .compactMap { $0["text"] as? String }
                        let blockText = textParts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                        if blockText.isEmpty { continue }
                        let kind: BlockKind = phase == "commentary" ? .thinking : .text
                        currentBlocks.append(AssistantBlock(kind: kind, text: blockText, toolCall: nil, timestamp: ts))
                    }
                    continue
                }

                // Encrypted reasoning — skip
                if ptype == "reasoning" { continue }

                // exec_command tool call
                if ptype == "function_call" {
                    let callId = payload["call_id"] as? String ?? ""
                    let name = payload["name"] as? String ?? "unknown"
                    var input: [String: Any] = [:]
                    if let args = payload["arguments"] as? String,
                       let argData = args.data(using: .utf8),
                       let parsed = try? JSONSerialization.jsonObject(with: argData) as? [String: Any] {
                        input = parsed
                    } else if let args = payload["arguments"] as? String {
                        input = ["raw": args]
                    }

                    var mappedName = name
                    if name == "exec_command" {
                        if let cmd = input["cmd"] as? String {
                            let workdir = input["workdir"] as? String
                            let fullCmd = workdir != nil ? "cd \(workdir!) && \(cmd)" : cmd
                            input = ["command": fullCmd]
                        }
                        mappedName = "Bash"
                    }

                    let tc = ToolCall(
                        toolUseId: callId,
                        name: mappedName,
                        input: input.mapValues { AnyCodable($0) },
                        result: nil,
                        resultTimestamp: nil,
                        isError: false
                    )
                    currentBlocks.append(AssistantBlock(kind: .toolUse, text: "", toolCall: tc, timestamp: ts))
                    pendingCalls[callId] = currentBlocks.count - 1
                    continue
                }

                // exec_command result
                if ptype == "function_call_output" {
                    let callId = payload["call_id"] as? String ?? ""
                    let output = payload["output"] as? String ?? ""
                    let cleaned = cleanCodexOutput(output)
                    if let blockIdx = pendingCalls[callId] {
                        currentBlocks[blockIdx].toolCall?.result = cleaned
                        currentBlocks[blockIdx].toolCall?.resultTimestamp = ts
                        currentBlocks[blockIdx].toolCall?.isError = output.contains("Process exited with code") && !output.contains("code 0")
                        pendingCalls.removeValue(forKey: callId)
                    }
                    continue
                }

                // apply_patch / custom tool calls
                if ptype == "custom_tool_call" {
                    let callId = payload["call_id"] as? String ?? ""
                    let name = payload["name"] as? String ?? "unknown"
                    var mappedName = name
                    var input: [String: Any]

                    if name == "apply_patch" {
                        let parsed = parseCodexPatch(payload["input"] as? String ?? "")
                        let isNew = parsed["isNew"] as? Bool ?? false
                        mappedName = isNew ? "Write" : "Edit"
                        input = parsed
                    } else {
                        input = ["raw": payload["input"] ?? ""]
                    }

                    let tc = ToolCall(
                        toolUseId: callId,
                        name: mappedName,
                        input: input.mapValues { AnyCodable($0) },
                        result: nil,
                        resultTimestamp: nil,
                        isError: false
                    )
                    currentBlocks.append(AssistantBlock(kind: .toolUse, text: "", toolCall: tc, timestamp: ts))
                    pendingCalls[callId] = currentBlocks.count - 1
                    continue
                }

                // custom tool call result
                if ptype == "custom_tool_call_output" {
                    let callId = payload["call_id"] as? String ?? ""
                    var output = ""
                    if let str = payload["output"] as? String {
                        output = str
                    } else if let dict = payload["output"] as? [String: Any],
                              let inner = dict["output"] as? String {
                        output = inner
                    }
                    if let blockIdx = pendingCalls[callId] {
                        currentBlocks[blockIdx].toolCall?.result = output.trimmingCharacters(in: .whitespacesAndNewlines)
                        currentBlocks[blockIdx].toolCall?.resultTimestamp = ts
                        if let dict = payload["output"] as? [String: Any],
                           let meta = dict["metadata"] as? [String: Any],
                           let exitCode = meta["exit_code"] as? Int {
                            currentBlocks[blockIdx].toolCall?.isError = exitCode != 0
                        }
                        pendingCalls.removeValue(forKey: callId)
                    }
                    continue
                }
            }
        }

        // Handle session ending without task_complete
        if inTurn && (!currentUserText.isEmpty || !currentBlocks.isEmpty) {
            turnIndex += 1
            turns.append(Turn(
                index: turnIndex,
                userText: currentUserText,
                blocks: currentBlocks,
                timestamp: currentTimestamp
            ))
        }

        // Drop empty turns and re-index
        var filtered = turns.filter { t in
            if !t.userText.isEmpty { return true }
            return t.blocks.contains { b in
                b.kind == .toolUse || (b.kind == .text && !b.text.isEmpty) || (b.kind == .thinking && !b.text.isEmpty)
            }
        }
        for j in 0..<filtered.count {
            filtered[j].index = j + 1
        }
        return filtered
    }

    // MARK: - 10. parseTranscript

    /// Main entry point: read a JSONL file and dispatch by format.
    static func parseTranscript(filePath: String) -> [Turn] {
        guard let text = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return []
        }
        return parseTranscriptFromText(text)
    }

    /// Parse transcript from raw text (useful for testing or in-memory data).
    static func parseTranscriptFromText(_ text: String) -> [Turn] {
        let format = detectFormatFromText(text)
        if format == .codex { return parseCodexTranscript(text) }

        let (entries, fmt) = parseJsonl(text)
        var turns: [Turn] = []
        var i = 0
        var turnIndex = 0

        while i < entries.count {
            let entry = entries[i]
            let role = entryRole(entry)

            if role == "user" {
                let message = entry["message"] as? [String: Any]
                let content = message?["content"]
                if isToolResultOnly(content) {
                    i += 1
                    continue
                }
                var userText = extractText(content)
                let timestamp = entry["timestamp"] as? String ?? ""
                i += 1

                // Absorb consecutive non-tool-result user messages
                while i < entries.count {
                    let next = entries[i]
                    let nextRole = entryRole(next)
                    if nextRole != "user" { break }
                    let nextMessage = next["message"] as? [String: Any]
                    let nextContent = nextMessage?["content"]
                    if isToolResultOnly(nextContent) { break }
                    let nextText = extractText(nextContent)
                    if !nextText.isEmpty {
                        userText = userText.isEmpty ? nextText : userText + "\n" + nextText
                    }
                    i += 1
                }

                // Extract system events (bg-task notifications)
                var systemEvents: [String] = []
                userText = replaceCapture(in: userText, pattern: #"\[bg-task:\s*(.+)\]"#) { _, groups in
                    systemEvents.append(groups[0])
                    return ""
                }
                userText = userText.trimmingCharacters(in: .whitespacesAndNewlines)

                var (assistantBlocks, nextI) = collectAssistantBlocks(entries, start: i)
                i = nextI
                i = attachToolResults(&assistantBlocks, entries: entries, resultStart: i)

                turnIndex += 1
                var turn = Turn(
                    index: turnIndex,
                    userText: userText,
                    blocks: assistantBlocks,
                    timestamp: timestamp
                )
                if !systemEvents.isEmpty { turn.systemEvents = systemEvents }
                turns.append(turn)

            } else if role == "assistant" {
                var (assistantBlocks, nextI) = collectAssistantBlocks(entries, start: i)
                i = nextI
                i = attachToolResults(&assistantBlocks, entries: entries, resultStart: i)

                if !turns.isEmpty {
                    turns[turns.count - 1].blocks.append(contentsOf: assistantBlocks)
                } else {
                    turnIndex += 1
                    turns.append(Turn(
                        index: turnIndex,
                        userText: "",
                        blocks: assistantBlocks,
                        timestamp: entry["timestamp"] as? String ?? ""
                    ))
                }
            } else {
                i += 1
            }
        }

        // Drop empty turns
        var filtered = turns.filter { t in
            if !t.userText.isEmpty { return true }
            if let events = t.systemEvents, !events.isEmpty { return true }
            return t.blocks.contains { b in
                if b.kind == .toolUse { return true }
                if b.kind == .text && !b.text.isEmpty && b.text != "No response requested." { return true }
                if b.kind == .thinking && !b.text.isEmpty { return true }
                return false
            }
        }
        // Re-index
        for j in 0..<filtered.count {
            filtered[j].index = j + 1
        }

        // Cursor: all assistant blocks except the last per turn are thinking
        if fmt == .cursor {
            for t in 0..<filtered.count {
                let blockCount = filtered[t].blocks.count
                if blockCount > 1 {
                    for j in 0..<(blockCount - 1) {
                        if filtered[t].blocks[j].kind == .text {
                            filtered[t].blocks[j].kind = .thinking
                        }
                    }
                }
            }
        }

        return filtered
    }

    // MARK: - 10b. parseAndChain (P1.2 — session chaining)

    /// Errors thrown by `parseAndChain(filePaths:)`.
    enum ChainError: Error, LocalizedError {
        case tooManyInputs(provided: Int, max: Int)
        case noTurnsParsed

        var errorDescription: String? {
            switch self {
            case .tooManyInputs(let provided, let max):
                return "Cannot chain \(provided) sessions — limit is \(max)."
            case .noTurnsParsed:
                return "None of the selected sessions yielded any turns."
            }
        }
    }

    /// Concatenate multiple transcripts into a single chronological turn stream.
    ///
    /// - Parses each path with the existing dispatcher.
    /// - Sorts each parsed session by its first turn's `timestamp` (ISO8601),
    ///   falling back to the file's modification date when no timestamp exists.
    /// - Re-indexes the resulting `Turn.index` sequentially starting at 1
    ///   to match the parser's existing 1-based numbering.
    /// - Throws `ChainError.tooManyInputs` for more than 20 inputs.
    static func parseAndChain(filePaths: [String]) async throws -> [Turn] {
        let maxInputs = 20
        guard filePaths.count <= maxInputs else {
            throw ChainError.tooManyInputs(provided: filePaths.count, max: maxInputs)
        }

        let fm = FileManager.default
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Parse each file off the main actor.
        let parsed: [(turns: [Turn], sortKey: Date)] = await withTaskGroup(
            of: (Int, [Turn], Date).self
        ) { group in
            for (idx, path) in filePaths.enumerated() {
                group.addTask {
                    let turns = TranscriptParser.parseTranscript(filePath: path)
                    // Prefer the first parsed turn's timestamp; otherwise the file mtime.
                    var key: Date = .distantFuture
                    if let firstTs = turns.first?.timestamp, !firstTs.isEmpty,
                       let dt = isoFormatter.date(from: firstTs)
                            ?? Self.parseFlexibleDate(firstTs) {
                        key = dt
                    } else if let attrs = try? fm.attributesOfItem(atPath: path),
                              let mtime = attrs[.modificationDate] as? Date {
                        key = mtime
                    }
                    return (idx, turns, key)
                }
            }
            var collected: [(Int, [Turn], Date)] = []
            for await item in group { collected.append(item) }
            // Preserve original input order as a stable tiebreaker.
            collected.sort { $0.0 < $1.0 }
            return collected.map { ($0.1, $0.2) }
        }

        // Sort sessions chronologically by their first-turn timestamp.
        let sorted = parsed.sorted { $0.sortKey < $1.sortKey }
        var chained: [Turn] = []
        chained.reserveCapacity(sorted.reduce(0) { $0 + $1.turns.count })
        for entry in sorted {
            chained.append(contentsOf: entry.turns)
        }
        guard !chained.isEmpty else { throw ChainError.noTurnsParsed }

        // Re-index globally (1-based to match parser convention).
        for j in 0..<chained.count {
            chained[j].index = j + 1
        }
        return chained
    }

    // MARK: - 11. applyPacedTiming

    /// Replace timestamps with synthetic pacing based on content length.
    static func applyPacedTiming(_ turns: inout [Turn]) {
        var cursor: Int64 = 0  // ms from epoch
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for t in 0..<turns.count {
            turns[t].timestamp = formatter.string(from: Date(timeIntervalSince1970: Double(cursor) / 1000.0))
            cursor += 500  // brief pause before assistant responds

            for b in 0..<turns[t].blocks.count {
                turns[t].blocks[b].timestamp = formatter.string(from: Date(timeIntervalSince1970: Double(cursor) / 1000.0))
                let len = turns[t].blocks[b].text.count
                let timing = min(max(len * 30, 1000), 10000)
                cursor += Int64(timing)

                if turns[t].blocks[b].toolCall != nil {
                    turns[t].blocks[b].toolCall?.resultTimestamp = formatter.string(from: Date(timeIntervalSince1970: Double(cursor) / 1000.0))
                }
            }
        }
    }

    // MARK: - 12. filterTurns

    /// Filter turns by index range, exclusion set, or time range.
    static func filterTurns(_ turns: [Turn], options: FilterOptions = FilterOptions()) -> [Turn] {
        var result = turns

        if let (start, end) = options.turnRange {
            result = result.filter { $0.index >= start && $0.index <= end }
        }

        if let excluded = options.excludeTurns {
            result = result.filter { !excluded.contains($0.index) }
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let timeFrom = options.timeFrom {
            guard let dtFrom = isoFormatter.date(from: timeFrom) ?? parseFlexibleDate(timeFrom) else {
                return result
            }
            result = result.filter { t in
                guard let ts = t.timestamp, !ts.isEmpty,
                      let dt = isoFormatter.date(from: ts) ?? parseFlexibleDate(ts) else {
                    return false
                }
                return dt >= dtFrom
            }
        }

        if let timeTo = options.timeTo {
            guard let dtTo = isoFormatter.date(from: timeTo) ?? parseFlexibleDate(timeTo) else {
                return result
            }
            result = result.filter { t in
                guard let ts = t.timestamp, !ts.isEmpty,
                      let dt = isoFormatter.date(from: ts) ?? parseFlexibleDate(ts) else {
                    return false
                }
                return dt <= dtTo
            }
        }

        return result
    }

    // MARK: - Private Helpers

    /// Check if content contains only tool_result blocks.
    private static func isToolResultOnly(_ content: Any?) -> Bool {
        guard let arr = content as? [[String: Any]] else { return false }
        return arr.allSatisfy { $0["type"] as? String == "tool_result" }
    }

    /// Extract role from an entry (handles both Claude Code and normalized Cursor).
    private static func entryRole(_ entry: [String: Any]) -> String {
        if let msg = entry["message"] as? [String: Any],
           let role = msg["role"] as? String {
            return role
        }
        return entry["type"] as? String ?? ""
    }

    /// Strip Codex metadata prefix from command output.
    private static func cleanCodexOutput(_ output: String) -> String {
        var cleaned = output
        cleaned = cleaned.replacingOccurrences(of: #"^Chunk ID:.*\n?"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"(?m)^Wall time:.*\n?"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"(?m)^Process exited with code \d+\n?"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"(?m)^Original token count:.*\n?"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"(?m)^Output:\n?"#, with: "", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Regex replace with capture group access.
    private static func replaceCapture(in text: String, pattern: String, replacer: (String, [String]) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return text
        }
        let nsText = text as NSString
        var result = ""
        var lastEnd = 0

        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        for match in matches {
            // Append text before this match
            let beforeRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
            result += nsText.substring(with: beforeRange)

            // Gather capture groups
            let fullMatch = nsText.substring(with: match.range)
            var groups: [String] = []
            for g in 1..<match.numberOfRanges {
                let gRange = match.range(at: g)
                if gRange.location != NSNotFound {
                    groups.append(nsText.substring(with: gRange))
                } else {
                    groups.append("")
                }
            }

            result += replacer(fullMatch, groups)
            lastEnd = match.range.location + match.range.length
        }

        // Append remainder
        if lastEnd < nsText.length {
            result += nsText.substring(from: lastEnd)
        }

        return result
    }

    /// Parse dates that may not be strict ISO8601 with fractional seconds.
    private static func parseFlexibleDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let d = formatter.date(from: string) { return d }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let d = df.date(from: string) { return d }
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return df.date(from: string)
    }
}
