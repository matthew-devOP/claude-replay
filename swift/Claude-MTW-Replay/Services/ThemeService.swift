import Foundation

// MARK: - Built-in themes and custom theme loading

/// The ordered list of CSS variable names each theme must define.
private let themeVars: [String] = [
    "bg", "bg-surface", "bg-hover",
    "text", "text-dim", "text-bright",
    "accent", "accent-dim",
    "green", "blue", "orange", "red", "cyan",
    "border", "tool-bg", "thinking-bg",
]

/// A theme is a dictionary of CSS variable names to hex values,
/// plus an optional `extraCss` key for additional stylesheet rules.
typealias ThemeDict = [String: String]

// MARK: - Built-in theme definitions (exact hex values from themes.mjs)

private let builtinThemes: [String: ThemeDict] = [
    "claude-dark": [
        "bg": "#1f1b18",
        "bg-surface": "#2a2420",
        "bg-hover": "#362e28",
        "text": "#e8ddd1",
        "text-dim": "#988878",
        "text-bright": "#faf4eb",
        "accent": "#d97757",
        "accent-dim": "#a85a3f",
        "green": "#8dbb6e",
        "blue": "#7aafd4",
        "orange": "#e08c65",
        "red": "#e77666",
        "cyan": "#7dc8c8",
        "border": "#3a322c",
        "tool-bg": "#241e1b",
        "thinking-bg": "#1e1917",
    ],
    "claude-light": [
        "bg": "#faf4eb",
        "bg-surface": "#f0e8d9",
        "bg-hover": "#e4dac5",
        "text": "#3c2e23",
        "text-dim": "#8a7460",
        "text-bright": "#1f1410",
        "accent": "#cc6633",
        "accent-dim": "#a0401f",
        "green": "#5e8944",
        "blue": "#4a85b0",
        "orange": "#d97757",
        "red": "#c0523a",
        "cyan": "#4d9e9e",
        "border": "#d9ccb8",
        "tool-bg": "#f0e8d9",
        "thinking-bg": "#ecdecb",
    ],
    "tokyo-night": [
        "bg": "#1a1b26",
        "bg-surface": "#24253a",
        "bg-hover": "#2f3147",
        "text": "#c0caf5",
        "text-dim": "#565f89",
        "text-bright": "#e0e6ff",
        "accent": "#bb9af7",
        "accent-dim": "#7957a8",
        "green": "#9ece6a",
        "blue": "#7aa2f7",
        "orange": "#ff9e64",
        "red": "#f7768e",
        "cyan": "#7dcfff",
        "border": "#3b3d57",
        "tool-bg": "#1e1f33",
        "thinking-bg": "#1c1d2e",
    ],
    "monokai": [
        "bg": "#272822",
        "bg-surface": "#2d2e27",
        "bg-hover": "#3e3d32",
        "text": "#f8f8f2",
        "text-dim": "#75715e",
        "text-bright": "#ffffff",
        "accent": "#ae81ff",
        "accent-dim": "#7c5cbf",
        "green": "#a6e22e",
        "blue": "#66d9ef",
        "orange": "#fd971f",
        "red": "#f92672",
        "cyan": "#66d9ef",
        "border": "#49483e",
        "tool-bg": "#1e1f1c",
        "thinking-bg": "#1c1d1a",
    ],
    "solarized-dark": [
        "bg": "#002b36",
        "bg-surface": "#073642",
        "bg-hover": "#0a4050",
        "text": "#839496",
        "text-dim": "#586e75",
        "text-bright": "#fdf6e3",
        "accent": "#6c71c4",
        "accent-dim": "#4e5299",
        "green": "#859900",
        "blue": "#268bd2",
        "orange": "#cb4b16",
        "red": "#dc322f",
        "cyan": "#2aa198",
        "border": "#094959",
        "tool-bg": "#012934",
        "thinking-bg": "#012730",
    ],
    "github-light": [
        "bg": "#ffffff",
        "bg-surface": "#f6f8fa",
        "bg-hover": "#eaeef2",
        "text": "#1f2328",
        "text-dim": "#656d76",
        "text-bright": "#000000",
        "accent": "#8250df",
        "accent-dim": "#6639ba",
        "green": "#1a7f37",
        "blue": "#0969da",
        "orange": "#bc4c00",
        "red": "#cf222e",
        "cyan": "#0598bc",
        "border": "#d0d7de",
        "tool-bg": "#f6f8fa",
        "thinking-bg": "#f0f3f6",
    ],
    "dracula": [
        "bg": "#282a36",
        "bg-surface": "#2d2f3d",
        "bg-hover": "#383a4a",
        "text": "#f8f8f2",
        "text-dim": "#6272a4",
        "text-bright": "#ffffff",
        "accent": "#bd93f9",
        "accent-dim": "#9571d1",
        "green": "#50fa7b",
        "blue": "#8be9fd",
        "orange": "#ffb86c",
        "red": "#ff5555",
        "cyan": "#8be9fd",
        "border": "#44475a",
        "tool-bg": "#21222c",
        "thinking-bg": "#1e1f29",
    ],
    "bubbles": [
        "bg": "#f0f2f5",
        "bg-surface": "#ffffff",
        "bg-hover": "#e4e6eb",
        "text": "#1c1e21",
        "text-dim": "#65676b",
        "text-bright": "#000000",
        "accent": "#0084ff",
        "accent-dim": "#0066cc",
        "green": "#31a24c",
        "blue": "#0084ff",
        "orange": "#f5a623",
        "red": "#e4405f",
        "cyan": "#0097a7",
        "border": "#dddfe2",
        "tool-bg": "#e4e6eb",
        "thinking-bg": "#e8daef",
        "extraCss": """

      .turn { margin-bottom: 16px; }
      .user-msg {
        display: flex; align-items: flex-end; justify-content: flex-end; gap: 8px; margin-bottom: 12px;
      }
      .user-msg::after {
        content: "\\1F464"; font-size: 24px; flex-shrink: 0; line-height: 1;
      }
      .user-prompt { display: none; }
      .user-text {
        background: #0084ff; color: #fff; border-radius: 18px 18px 4px 18px;
        padding: 10px 16px; max-width: 75%; display: inline-block; font-weight: normal;
      }
      .turn-header-ts { color: #fff8; }
      .turn > :not(.user-msg):not(.block-wrapper) { padding-left: 40px; }
      .block-wrapper { padding-left: 40px; position: relative; }
      .block-wrapper::before {
        content: "\\1F916"; position: absolute; left: 4px; top: 4px; font-size: 20px; line-height: 1;
      }
      .block-wrapper + .block-wrapper::before { content: none; }
      .assistant-text {
        background: #fff; border-radius: 18px 18px 18px 4px;
        padding: 10px 16px; max-width: 85%; display: inline-block; color: #1c1e21;
        border: 1px solid #dddfe2;
      }
      .thinking-block {
        background: #f3ebfa; border-radius: 18px 18px 18px 4px;
        padding: 10px 16px; max-width: 85%; border: 1px solid #d6c8e4;
      }
      .thinking-header { color: #6b3fa0; }
      .thinking-body { color: #3d2066; }
      .tool-block, .tool-group {
        background: #fff; border-radius: 12px;
        padding: 8px 12px; max-width: 85%; border: 1px solid #dddfe2;
      }
      .tool-header { color: #1c1e21; }
      .tool-name { color: #0066cc; }
      .bookmark-divider { color: #1c1e21; border-color: #dddfe2; }
    """,
    ],
]

// MARK: - Public API

enum ThemeService {

    static func getTheme(_ name: String) throws -> ThemeDict {
        guard let theme = builtinThemes[name] else {
            let available = builtinThemes.keys.sorted().joined(separator: ", ")
            throw NSError(
                domain: "ThemeService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unknown theme '\(name)'. Available: \(available)"]
            )
        }
        return theme
    }

    static func listThemes() -> [String] {
        builtinThemes.keys.sorted()
    }

    static func getAllThemes() -> [String: ThemeDict] {
        var result: [String: ThemeDict] = [:]
        for (name, theme) in builtinThemes {
            var vars: ThemeDict = [:]
            for v in themeVars {
                if let value = theme[v] {
                    vars[v] = value
                }
            }
            result[name] = vars
        }
        return result
    }

    static func loadThemeFile(_ filePath: String) throws -> ThemeDict {
        let url = URL(fileURLWithPath: filePath)
        let data = try Data(contentsOf: url)

        guard let custom = try JSONSerialization.jsonObject(with: data) as? [String: String] else {
            throw NSError(
                domain: "ThemeService",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Theme file must be a JSON object"]
            )
        }

        guard let defaults = builtinThemes["tokyo-night"] else {
            return custom
        }

        var merged = defaults
        for (key, value) in custom {
            merged[key] = value
        }
        return merged
    }

    static func themeToCss(_ theme: ThemeDict) -> String {
        var lines: [String] = []
        for v in themeVars {
            if let value = theme[v] {
                lines.append("  --\(v): \(value);")
            }
        }
        var css = ":root {\n" + lines.joined(separator: "\n") + "\n}"
        if let extra = theme["extraCss"] {
            css += "\n" + extra
        }
        return css
    }
}
