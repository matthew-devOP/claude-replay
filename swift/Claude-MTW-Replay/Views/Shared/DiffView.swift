import SwiftUI

struct DiffView: View {
    @Environment(AppState.self) private var appState
    let oldText: String
    let newText: String
    var filePath: String? = nil
    var contextLines: Int = 3

    private enum DiffLineKind {
        case context, addition, deletion
    }

    private struct DiffLine: Identifiable {
        let id: Int
        let kind: DiffLineKind
        let text: String
    }

    var body: some View {
        let lines = computeDiff()
        VStack(alignment: .leading, spacing: 0) {
            if let fp = filePath {
                Text(fp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(DesignTokens.space4)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(lines) { line in
                        diffLineView(line)
                    }
                }
            }
            .padding(DesignTokens.space4)
        }
        .background(appState.theme.toolBg, in: RoundedRectangle(cornerRadius: DesignTokens.cornerSmall))
    }

    @ViewBuilder
    private func diffLineView(_ line: DiffLine) -> some View {
        let theme = appState.theme
        let (prefix, fg, bg): (String, Color, Color) = {
            switch line.kind {
            case .deletion:  return ("-", theme.red, theme.red)
            case .addition:  return ("+", theme.green, theme.green)
            case .context:   return (" ", theme.text, Color.clear)
            }
        }()
        Text("\(prefix) \(line.text)")
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignTokens.space4)
            .background(bg.opacity(line.kind == .context ? 0 : 0.1))
    }

    // MARK: - LCS-based line diff

    private func computeDiff() -> [DiffLine] {
        let oldLines = oldText.components(separatedBy: "\n")
        let newLines = newText.components(separatedBy: "\n")
        let m = oldLines.count
        let n = newLines.count

        // Build LCS table
        var dp = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        for i in 1...max(m, 1) {
            guard i <= m else { break }
            for j in 1...max(n, 1) {
                guard j <= n else { break }
                if oldLines[i - 1] == newLines[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }

        // Backtrack to produce raw diff operations
        enum RawOp {
            case equal(String)
            case delete(String)
            case insert(String)
        }

        var ops: [RawOp] = []
        var i = m, j = n
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && oldLines[i - 1] == newLines[j - 1] {
                ops.append(.equal(oldLines[i - 1]))
                i -= 1; j -= 1
            } else if j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j]) {
                ops.append(.insert(newLines[j - 1]))
                j -= 1
            } else {
                ops.append(.delete(oldLines[i - 1]))
                i -= 1
            }
        }
        ops.reverse()

        // Apply context window: only show context lines around changes
        let showAll = ops.count <= 40
        if showAll {
            return ops.enumerated().map { idx, op in
                switch op {
                case .equal(let t):  return DiffLine(id: idx, kind: .context, text: t)
                case .delete(let t): return DiffLine(id: idx, kind: .deletion, text: t)
                case .insert(let t): return DiffLine(id: idx, kind: .addition, text: t)
                }
            }
        }

        // Mark which indices should be visible (changes + surrounding context)
        var visible = [Bool](repeating: false, count: ops.count)
        for (idx, op) in ops.enumerated() {
            switch op {
            case .delete, .insert:
                let lo = max(0, idx - contextLines)
                let hi = min(ops.count - 1, idx + contextLines)
                for k in lo...hi { visible[k] = true }
            case .equal: break
            }
        }

        var result: [DiffLine] = []
        var lineId = 0
        var lastVisible = false
        for (idx, op) in ops.enumerated() {
            if visible[idx] {
                if !lastVisible && idx > 0 {
                    result.append(DiffLine(id: lineId, kind: .context, text: "..."))
                    lineId += 1
                }
                let kind: DiffLineKind
                let text: String
                switch op {
                case .equal(let t):  kind = .context;  text = t
                case .delete(let t): kind = .deletion;  text = t
                case .insert(let t): kind = .addition; text = t
                }
                result.append(DiffLine(id: lineId, kind: kind, text: text))
                lineId += 1
                lastVisible = true
            } else {
                lastVisible = false
            }
        }
        return result
    }
}
