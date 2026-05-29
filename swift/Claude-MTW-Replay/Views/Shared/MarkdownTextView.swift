import SwiftUI

struct MarkdownTextView: View {
    @Environment(AppState.self) private var appState
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.space6) {
            ForEach(Array(parseBlocks(markdown).enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
        .textSelection(.enabled)
    }

    // MARK: - Block types

    private enum Block {
        case heading(Int, String)            // level 1-6, text
        case codeBlock(String, String)       // language, code
        case unorderedList([String])         // items
        case orderedList([String])           // items
        case blockquote(String)             // text
        case table([[String]])              // rows of cells
        case paragraph(String)              // inline markdown text
        case horizontalRule
    }

    // MARK: - Block parser

    private func parseBlocks(_ text: String) -> [Block] {
        var blocks: [Block] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Blank line
            if trimmed.isEmpty {
                i += 1
                continue
            }

            // Horizontal rule
            if trimmed.count >= 3 && trimmed.allSatisfy({ $0 == "-" || $0 == "*" || $0 == "_" || $0 == " " }) {
                let stripped = trimmed.filter { $0 != " " }
                if stripped.count >= 3 && Set(stripped).count == 1 {
                    blocks.append(.horizontalRule)
                    i += 1
                    continue
                }
            }

            // Code block (fenced)
            if trimmed.hasPrefix("```") {
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count {
                    if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        i += 1
                        break
                    }
                    codeLines.append(lines[i])
                    i += 1
                }
                blocks.append(.codeBlock(lang, codeLines.joined(separator: "\n")))
                continue
            }

            // Heading
            if let match = trimmed.range(of: #"^(#{1,6})\s+"#, options: .regularExpression) {
                let hashes = trimmed[match].filter { $0 == "#" }.count
                let content = String(trimmed[match.upperBound...])
                blocks.append(.heading(hashes, content))
                i += 1
                continue
            }

            // Table (lines containing |)
            if trimmed.contains("|") && i + 1 < lines.count {
                let nextTrimmed = lines[i + 1].trimmingCharacters(in: .whitespaces)
                // Check if next line is separator row (e.g. |---|---|)
                if nextTrimmed.contains("|") && nextTrimmed.contains("-") {
                    var tableRows: [[String]] = []
                    // Parse header
                    tableRows.append(parseTableRow(line))
                    i += 2 // skip header and separator
                    while i < lines.count {
                        let rowLine = lines[i].trimmingCharacters(in: .whitespaces)
                        if rowLine.isEmpty || !rowLine.contains("|") { break }
                        tableRows.append(parseTableRow(lines[i]))
                        i += 1
                    }
                    blocks.append(.table(tableRows))
                    continue
                }
            }

            // Unordered list
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                var items: [String] = []
                while i < lines.count {
                    let l = lines[i].trimmingCharacters(in: .whitespaces)
                    if l.hasPrefix("- ") || l.hasPrefix("* ") || l.hasPrefix("+ ") {
                        items.append(String(l.dropFirst(2)))
                        i += 1
                    } else if l.hasPrefix("  ") && !items.isEmpty {
                        // Continuation line
                        items[items.count - 1] += " " + l.trimmingCharacters(in: .whitespaces)
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(.unorderedList(items))
                continue
            }

            // Ordered list
            if let _ = trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                var items: [String] = []
                while i < lines.count {
                    let l = lines[i].trimmingCharacters(in: .whitespaces)
                    if let m = l.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                        items.append(String(l[m.upperBound...]))
                        i += 1
                    } else if l.hasPrefix("  ") && !items.isEmpty {
                        items[items.count - 1] += " " + l.trimmingCharacters(in: .whitespaces)
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(.orderedList(items))
                continue
            }

            // Blockquote
            if trimmed.hasPrefix("> ") || trimmed == ">" {
                var quoteLines: [String] = []
                while i < lines.count {
                    let l = lines[i].trimmingCharacters(in: .whitespaces)
                    if l.hasPrefix("> ") {
                        quoteLines.append(String(l.dropFirst(2)))
                        i += 1
                    } else if l == ">" {
                        quoteLines.append("")
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(.blockquote(quoteLines.joined(separator: "\n")))
                continue
            }

            // Paragraph: collect contiguous non-empty, non-special lines
            var paraLines: [String] = []
            while i < lines.count {
                let l = lines[i]
                let lt = l.trimmingCharacters(in: .whitespaces)
                if lt.isEmpty || lt.hasPrefix("#") || lt.hasPrefix("```") || lt.hasPrefix("- ") || lt.hasPrefix("* ") || lt.hasPrefix("+ ") || lt.hasPrefix("> ") {
                    break
                }
                if let _ = lt.range(of: #"^\d+\.\s+"#, options: .regularExpression) { break }
                paraLines.append(l)
                i += 1
            }
            if !paraLines.isEmpty {
                blocks.append(.paragraph(paraLines.joined(separator: " ")))
            }
        }

        return blocks
    }

    private func parseTableRow(_ line: String) -> [String] {
        line.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Block rendering

    @ViewBuilder
    private func renderBlock(_ block: Block) -> some View {
        switch block {
        case .heading(let level, let text):
            renderInlineMarkdown(text)
                .font(fontForHeading(level))
                .fontWeight(.bold)
                .padding(.top, level <= 2 ? 6 : 2)

        case .codeBlock(let lang, let code):
            CodeBlockView(code: code, language: lang)

        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: DesignTokens.space4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: DesignTokens.space6) {
                        Text("\u{2022}")
                            .foregroundStyle(.secondary)
                        renderInlineMarkdown(item)
                    }
                }
            }
            .padding(.leading, DesignTokens.space8)

        case .orderedList(let items):
            VStack(alignment: .leading, spacing: DesignTokens.space4) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .firstTextBaseline, spacing: DesignTokens.space6) {
                        Text("\(idx + 1).")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        renderInlineMarkdown(item)
                    }
                }
            }
            .padding(.leading, DesignTokens.space8)

        case .blockquote(let text):
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 3)
                renderInlineMarkdown(text)
                    .foregroundStyle(.secondary)
                    .padding(.leading, DesignTokens.space8)
            }
            .padding(.vertical, DesignTokens.space2)

        case .table(let rows):
            renderTable(rows)

        case .paragraph(let text):
            renderInlineMarkdown(text)

        case .horizontalRule:
            Divider()
                .padding(.vertical, DesignTokens.space4)
        }
    }

    private func fontForHeading(_ level: Int) -> Font {
        switch level {
        case 1: return .title
        case 2: return .title2
        case 3: return .title3
        case 4: return .headline
        default: return .subheadline
        }
    }

    // MARK: - Inline markdown rendering

    private func renderInlineMarkdown(_ text: String) -> Text {
        parseInline(text)
    }

    /// Parses inline markdown (bold, italic, code, links, strikethrough) into a styled Text.
    private func parseInline(_ input: String) -> Text {
        var result = Text("")
        var remaining = input[input.startIndex..<input.endIndex]

        while !remaining.isEmpty {
            // Bold+Italic ***text*** or ___text___
            if let (content, after) = extractDelimited(remaining, delimiter: "***") ??
               extractDelimited(remaining, delimiter: "___") {
                result = result + parseInline(String(content)).bold().italic()
                remaining = after
                continue
            }

            // Bold **text** or __text__
            if let (content, after) = extractDelimited(remaining, delimiter: "**") ??
               extractDelimited(remaining, delimiter: "__") {
                result = result + parseInline(String(content)).bold()
                remaining = after
                continue
            }

            // Italic *text* or _text_
            if let (content, after) = extractDelimited(remaining, delimiter: "*") ??
               extractDelimited(remaining, delimiter: "_") {
                result = result + parseInline(String(content)).italic()
                remaining = after
                continue
            }

            // Strikethrough ~~text~~
            if let (content, after) = extractDelimited(remaining, delimiter: "~~") {
                result = result + Text(content).strikethrough()
                remaining = after
                continue
            }

            // Inline code `text`
            if remaining.hasPrefix("`") {
                let after = remaining.dropFirst()
                if let endIdx = after.firstIndex(of: "`") {
                    let code = after[after.startIndex..<endIdx]
                    result = result + Text(code)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(appState.theme.blue)
                    remaining = after[after.index(after: endIdx)...]
                    continue
                }
            }

            // Link [text](url)
            if remaining.hasPrefix("[") {
                if let closeBracket = remaining.firstIndex(of: "]") {
                    let linkText = remaining[remaining.index(after: remaining.startIndex)..<closeBracket]
                    let afterBracket = remaining[remaining.index(after: closeBracket)...]
                    if afterBracket.hasPrefix("(") {
                        if let closeParen = afterBracket.firstIndex(of: ")") {
                            let url = afterBracket[afterBracket.index(after: afterBracket.startIndex)..<closeParen]
                            result = result + Text(linkText).foregroundColor(appState.theme.blue).underline()
                            remaining = afterBracket[afterBracket.index(after: closeParen)...]
                            _ = url // URL noted but Text doesn't support tappable links
                            continue
                        }
                    }
                }
            }

            // Plain character
            result = result + Text(String(remaining.first!))
            remaining = remaining.dropFirst()
        }

        return result
    }

    /// Extract content between matching delimiter pairs at the start of the substring.
    private func extractDelimited(_ input: Substring, delimiter: String) -> (Substring, Substring)? {
        guard input.hasPrefix(delimiter) else { return nil }
        let after = input.dropFirst(delimiter.count)
        guard !after.isEmpty, !after.hasPrefix(delimiter) else { return nil }
        if let range = after.range(of: delimiter) {
            let content = after[after.startIndex..<range.lowerBound]
            guard !content.isEmpty else { return nil }
            let rest = after[range.upperBound...]
            return (content, rest)
        }
        return nil
    }

    // MARK: - Table rendering

    @ViewBuilder
    private func renderTable(_ rows: [[String]]) -> some View {
        if rows.isEmpty { EmptyView() }
        else {
            let header = rows.first!
            let body = Array(rows.dropFirst())
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header row
                    HStack(spacing: 0) {
                        ForEach(Array(header.enumerated()), id: \.offset) { _, cell in
                            Text(cell)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, DesignTokens.space8)
                                .padding(.vertical, DesignTokens.space4)
                                .frame(minWidth: 60, alignment: .leading)
                        }
                    }
                    .background(appState.theme.bgHover.opacity(0.6))

                    Divider()

                    // Body rows
                    ForEach(Array(body.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 0) {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                                Text(cell)
                                    .font(.caption)
                                    .padding(.horizontal, DesignTokens.space8)
                                    .padding(.vertical, DesignTokens.space4)
                                    .frame(minWidth: 60, alignment: .leading)
                            }
                        }
                    }
                }
            }
        }
    }
}
