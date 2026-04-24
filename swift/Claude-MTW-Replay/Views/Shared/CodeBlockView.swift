import SwiftUI

struct CodeBlockView: View {
    @Environment(AppState.self) private var appState
    let code: String
    var language: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !language.isEmpty {
                Text(language)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
            }
            ScrollView(.horizontal) {
                Text(highlightedCode)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
            }
        }
        .background(appState.theme.bg, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(appState.theme.border, lineWidth: 1))
    }

    // MARK: - Syntax Highlighting

    private var highlightedCode: AttributedString {
        let langKey = language.lowercased()
        let rules = SyntaxRules.rules(for: langKey, theme: appState.theme)
        let fullRange = NSRange(location: 0, length: (code as NSString).length)

        // Build a per-UTF16-offset color array, higher priority rules overwrite lower
        var colorMap = [Int: (Color, Int)]() // offset -> (color, priority)

        let orderedRules = rules.sorted { $0.priority < $1.priority }
        for rule in orderedRules {
            guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: rule.options) else { continue }
            for match in regex.matches(in: code, range: fullRange) {
                let r = match.range
                for offset in r.location..<(r.location + r.length) {
                    if let existing = colorMap[offset], existing.1 > rule.priority { continue }
                    colorMap[offset] = (rule.color, rule.priority)
                }
            }
        }

        // Build attributed string by grouping consecutive characters with same color
        var result = AttributedString()
        let utf16 = code.utf16
        var currentColor: Color? = nil
        var currentChars: [unichar] = []

        func flush() {
            guard !currentChars.isEmpty else { return }
            let str = String(utf16CodeUnits: currentChars, count: currentChars.count)
            var attr = AttributedString(str)
            if let c = currentColor {
                attr.foregroundColor = c
            }
            result.append(attr)
            currentChars = []
        }

        for (i, unit) in utf16.enumerated() {
            let c = colorMap[i]?.0
            if c != currentColor {
                flush()
                currentColor = c
            }
            currentChars.append(unit)
        }
        flush()

        return result
    }
}

// MARK: - Syntax Rules

private struct HighlightRule {
    let pattern: String
    let color: Color
    let options: NSRegularExpression.Options
    let priority: Int // lower = applied first (can be overwritten)

    init(_ pattern: String, _ color: Color, priority: Int = 0, options: NSRegularExpression.Options = []) {
        self.pattern = pattern
        self.color = color
        self.options = options
        self.priority = priority
    }
}

private enum SyntaxRules {
    static func rules(for language: String, theme: Theme) -> [HighlightRule] {
        let keyword   = theme.accent
        let string    = theme.green
        let comment   = theme.textDim
        let number    = theme.orange
        let type      = theme.cyan
        let function_ = theme.blue
        let `operator` = theme.cyan

        var r: [HighlightRule] = []

        // Numbers (int, float, hex)
        r.append(HighlightRule(#"\b(?:0x[\da-fA-F]+|\d+\.?\d*(?:[eE][+-]?\d+)?)\b"#, number, priority: 0))

        // Language-specific keywords and patterns
        switch language {
        case "swift":
            r.append(HighlightRule(
                #"\b(?:func|let|var|if|else|guard|switch|case|default|for|in|while|repeat|return|throw|throws|try|catch|do|import|struct|class|enum|protocol|extension|typealias|associatedtype|init|deinit|self|Self|super|nil|true|false|where|is|as|private|fileprivate|internal|public|open|static|override|mutating|nonmutating|lazy|weak|unowned|some|any|async|await|actor|nonisolated|@State|@Binding|@Published|@ObservedObject|@StateObject|@EnvironmentObject|@Environment|@MainActor)\b"#,
                keyword, priority: 1
            ))
            r.append(HighlightRule(#"\b[A-Z]\w*\b"#, type, priority: 0))
            r.append(HighlightRule(#"(?<=\.)\w+(?=\()"#, function_, priority: 2))
            // Strings (double-quoted, supports escaped quotes)
            r.append(HighlightRule(#""(?:[^"\\]|\\.)*""#, string, priority: 8))
            // Comments
            r.append(HighlightRule(#"//[^\n]*"#, comment, priority: 9))
            r.append(HighlightRule(#"/\*[\s\S]*?\*/"#, comment, priority: 9, options: [.dotMatchesLineSeparators]))

        case "javascript", "js", "typescript", "ts", "jsx", "tsx":
            r.append(HighlightRule(
                #"\b(?:function|const|let|var|if|else|for|while|do|switch|case|default|break|continue|return|throw|try|catch|finally|new|delete|typeof|instanceof|void|in|of|class|extends|super|this|import|export|from|as|default|async|await|yield|true|false|null|undefined|NaN|Infinity)\b"#,
                keyword, priority: 1
            ))
            r.append(HighlightRule(#"(?:=>)"#, `operator`, priority: 2))
            r.append(HighlightRule(#"\b[A-Z]\w*\b"#, type, priority: 0))
            r.append(HighlightRule(#""(?:[^"\\]|\\.)*""#, string, priority: 8))
            r.append(HighlightRule(#"'(?:[^'\\]|\\.)*'"#, string, priority: 8))
            r.append(HighlightRule(#"`(?:[^`\\]|\\.)*`"#, string, priority: 8, options: [.dotMatchesLineSeparators]))
            r.append(HighlightRule(#"//[^\n]*"#, comment, priority: 9))
            r.append(HighlightRule(#"/\*[\s\S]*?\*/"#, comment, priority: 9, options: [.dotMatchesLineSeparators]))

        case "python", "py":
            r.append(HighlightRule(
                #"\b(?:def|class|if|elif|else|for|while|break|continue|return|yield|try|except|finally|raise|import|from|as|with|pass|lambda|and|or|not|is|in|True|False|None|self|global|nonlocal|assert|del|async|await)\b"#,
                keyword, priority: 1
            ))
            r.append(HighlightRule(#"\b[A-Z]\w*\b"#, type, priority: 0))
            r.append(HighlightRule(#"@\w+"#, function_, priority: 2)) // decorators
            r.append(HighlightRule(#"\"\"\"[\s\S]*?\"\"\""#, string, priority: 8, options: [.dotMatchesLineSeparators]))
            r.append(HighlightRule(#"'''[\s\S]*?'''"#, string, priority: 8, options: [.dotMatchesLineSeparators]))
            r.append(HighlightRule(#""(?:[^"\\]|\\.)*""#, string, priority: 8))
            r.append(HighlightRule(#"'(?:[^'\\]|\\.)*'"#, string, priority: 8))
            r.append(HighlightRule(#"#[^\n]*"#, comment, priority: 9))

        case "bash", "sh", "zsh", "shell":
            r.append(HighlightRule(
                #"\b(?:if|then|else|elif|fi|for|while|do|done|case|esac|in|function|return|exit|local|export|source|alias|unalias|set|unset|readonly|shift|break|continue|true|false)\b"#,
                keyword, priority: 1
            ))
            r.append(HighlightRule(#"\$\{?\w+\}?"#, type, priority: 2)) // variables
            r.append(HighlightRule(#""(?:[^"\\]|\\.)*""#, string, priority: 8))
            r.append(HighlightRule(#"'[^']*'"#, string, priority: 8))
            r.append(HighlightRule(#"#[^\n]*"#, comment, priority: 9))

        default:
            // Generic fallback: common C-family keywords
            r.append(HighlightRule(
                #"\b(?:if|else|for|while|do|switch|case|default|break|continue|return|function|class|struct|enum|import|export|true|false|null|nil|void|int|float|double|string|bool|var|let|const)\b"#,
                keyword, priority: 1
            ))
            r.append(HighlightRule(#"\b[A-Z]\w*\b"#, type, priority: 0))
            r.append(HighlightRule(#""(?:[^"\\]|\\.)*""#, string, priority: 8))
            r.append(HighlightRule(#"'(?:[^'\\]|\\.)*'"#, string, priority: 8))
            r.append(HighlightRule(#"//[^\n]*"#, comment, priority: 9))
            r.append(HighlightRule(#"#[^\n]*"#, comment, priority: 9))
            r.append(HighlightRule(#"/\*[\s\S]*?\*/"#, comment, priority: 9, options: [.dotMatchesLineSeparators]))
        }

        return r
    }
}
