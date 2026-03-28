import Foundation

// MARK: - MarkdownExporter

enum MarkdownExporter {

    /// Convert turns to a Markdown string, mirroring turnsToMarkdown from editor-server.mjs.
    static func turnsToMarkdown(_ turns: [Turn], title: String? = nil) -> String {
        var lines: [String] = ["# \(title ?? "Claude Session")", ""]

        for turn in turns {
            lines.append(contentsOf: ["---", ""])

            var header = "## Turn \(turn.index)"
            if let ts = turn.timestamp, let date = parseTimestamp(ts) {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withSpaceBetweenDateAndTime]
                formatter.timeZone = TimeZone(identifier: "UTC")
                let formatted = formatter.string(from: date) + " UTC"
                header += " — \(formatted)"
            }
            lines.append(contentsOf: [header, ""])

            if !turn.userText.isEmpty {
                lines.append(contentsOf: ["### User", "", turn.userText, ""])
            }

            if let events = turn.systemEvents, !events.isEmpty {
                for ev in events {
                    lines.append("> **System:** \(ev)")
                    lines.append("")
                }
            }

            if !turn.blocks.isEmpty {
                lines.append(contentsOf: ["### Assistant", ""])

                for block in turn.blocks {
                    switch block.kind {
                    case "text":
                        lines.append(contentsOf: [block.text, ""])

                    case "thinking":
                        lines.append(contentsOf: [
                            "<details>",
                            "<summary>Thinking</summary>",
                            "",
                            block.text,
                            "",
                            "</details>",
                            ""
                        ])

                    case "tool_use":
                        guard let tc = block.toolCall else { continue }
                        lines.append("#### Tool: \(tc.name)")

                        let input = tc.input
                        if tc.name == "Bash", let cmd = stringValue(input["command"]) {
                            lines.append(contentsOf: ["", "```bash", cmd, "```", ""])
                        } else if (tc.name == "Edit" || tc.name == "Write"),
                                  let filePath = stringValue(input["file_path"]) {
                            lines.append(contentsOf: ["", "**File:** `\(filePath)`"])

                            if tc.name == "Edit", let oldStr = stringValue(input["old_string"]) {
                                let newStr = stringValue(input["new_string"]) ?? ""
                                lines.append("")
                                lines.append("```diff")
                                for l in oldStr.split(separator: "\n", omittingEmptySubsequences: false) {
                                    lines.append("- \(l)")
                                }
                                for l in newStr.split(separator: "\n", omittingEmptySubsequences: false) {
                                    lines.append("+ \(l)")
                                }
                                lines.append(contentsOf: ["```", ""])
                            } else if let content = stringValue(input["content"]) {
                                lines.append(contentsOf: ["", "```", content, "```", ""])
                            }
                        } else {
                            // Generic: render input as JSON
                            if let jsonData = try? JSONSerialization.data(
                                withJSONObject: input.mapValues(\.value),
                                options: [.prettyPrinted, .sortedKeys]),
                               let jsonStr = String(data: jsonData, encoding: .utf8) {
                                lines.append(contentsOf: ["", "```json", jsonStr, "```", ""])
                            } else {
                                lines.append("")
                            }
                        }

                        if let result = tc.result {
                            let label = tc.isError == true ? "**Error:**" : "**Result:**"
                            lines.append(contentsOf: [label, "", "```", result, "```", ""])
                        }

                    default:
                        break
                    }
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Private helpers

    /// Extract a String from an AnyCodable value.
    private static func stringValue(_ v: AnyCodable?) -> String? {
        guard let v = v else { return nil }
        return v.value as? String
    }

    /// Parse a timestamp string into a Date.
    private static func parseTimestamp(_ ts: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: ts) { return date }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: ts)
    }
}
