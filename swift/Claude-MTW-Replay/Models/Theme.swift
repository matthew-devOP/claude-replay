import SwiftUI

// MARK: - ThemeName

enum ThemeName: String, Codable, CaseIterable, Identifiable, Sendable {
    case claudeDark = "claude-dark"
    case claudeLight = "claude-light"
    case tokyoNight = "tokyo-night"
    case monokai
    case solarizedDark = "solarized-dark"
    case githubLight = "github-light"
    case dracula
    case bubbles

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claudeDark: return "Claude Dark"
        case .claudeLight: return "Claude Light"
        case .tokyoNight: return "Tokyo Night"
        case .monokai: return "Monokai"
        case .solarizedDark: return "Solarized Dark"
        case .githubLight: return "GitHub Light"
        case .dracula: return "Dracula"
        case .bubbles: return "Bubbles"
        }
    }
}

// MARK: - Theme

struct Theme: Sendable, Equatable {
    let name: ThemeName
    let bg: Color
    let bgSurface: Color
    let bgHover: Color
    let text: Color
    let textDim: Color
    let textBright: Color
    let accent: Color
    let accentDim: Color
    let green: Color
    let blue: Color
    let orange: Color
    let red: Color
    let cyan: Color
    let border: Color
    let toolBg: Color
    let thinkingBg: Color
    let extraCss: String?

    var isDark: Bool {
        name != .githubLight && name != .bubbles && name != .claudeLight
    }

    // MARK: - Built-in Themes

    static let claudeDark = Theme(
        name: .claudeDark,
        bg: Color(hex: "#1f1b18"),
        bgSurface: Color(hex: "#2a2420"),
        bgHover: Color(hex: "#362e28"),
        text: Color(hex: "#e8ddd1"),
        textDim: Color(hex: "#988878"),
        textBright: Color(hex: "#faf4eb"),
        accent: Color(hex: "#d97757"),
        accentDim: Color(hex: "#a85a3f"),
        green: Color(hex: "#8dbb6e"),
        blue: Color(hex: "#7aafd4"),
        orange: Color(hex: "#e08c65"),
        red: Color(hex: "#e77666"),
        cyan: Color(hex: "#7dc8c8"),
        border: Color(hex: "#3a322c"),
        toolBg: Color(hex: "#241e1b"),
        thinkingBg: Color(hex: "#1e1917"),
        extraCss: nil
    )

    static let claudeLight = Theme(
        name: .claudeLight,
        bg: Color(hex: "#faf4eb"),
        bgSurface: Color(hex: "#f0e8d9"),
        bgHover: Color(hex: "#e4dac5"),
        text: Color(hex: "#3c2e23"),
        textDim: Color(hex: "#8a7460"),
        textBright: Color(hex: "#1f1410"),
        accent: Color(hex: "#cc6633"),
        accentDim: Color(hex: "#a0401f"),
        green: Color(hex: "#5e8944"),
        blue: Color(hex: "#4a85b0"),
        orange: Color(hex: "#d97757"),
        red: Color(hex: "#c0523a"),
        cyan: Color(hex: "#4d9e9e"),
        border: Color(hex: "#d9ccb8"),
        toolBg: Color(hex: "#f0e8d9"),
        thinkingBg: Color(hex: "#ecdecb"),
        extraCss: nil
    )

    static let tokyoNight = Theme(
        name: .tokyoNight,
        bg: Color(hex: "#1a1b26"),
        bgSurface: Color(hex: "#24253a"),
        bgHover: Color(hex: "#2f3147"),
        text: Color(hex: "#c0caf5"),
        textDim: Color(hex: "#565f89"),
        textBright: Color(hex: "#e0e6ff"),
        accent: Color(hex: "#bb9af7"),
        accentDim: Color(hex: "#7957a8"),
        green: Color(hex: "#9ece6a"),
        blue: Color(hex: "#7aa2f7"),
        orange: Color(hex: "#ff9e64"),
        red: Color(hex: "#f7768e"),
        cyan: Color(hex: "#7dcfff"),
        border: Color(hex: "#3b3d57"),
        toolBg: Color(hex: "#1e1f33"),
        thinkingBg: Color(hex: "#1c1d2e"),
        extraCss: nil
    )

    static let monokai = Theme(
        name: .monokai,
        bg: Color(hex: "#272822"),
        bgSurface: Color(hex: "#2d2e27"),
        bgHover: Color(hex: "#3e3d32"),
        text: Color(hex: "#f8f8f2"),
        textDim: Color(hex: "#75715e"),
        textBright: Color(hex: "#ffffff"),
        accent: Color(hex: "#ae81ff"),
        accentDim: Color(hex: "#7c5cbf"),
        green: Color(hex: "#a6e22e"),
        blue: Color(hex: "#66d9ef"),
        orange: Color(hex: "#fd971f"),
        red: Color(hex: "#f92672"),
        cyan: Color(hex: "#66d9ef"),
        border: Color(hex: "#49483e"),
        toolBg: Color(hex: "#1e1f1c"),
        thinkingBg: Color(hex: "#1c1d1a"),
        extraCss: nil
    )

    static let solarizedDark = Theme(
        name: .solarizedDark,
        bg: Color(hex: "#002b36"),
        bgSurface: Color(hex: "#073642"),
        bgHover: Color(hex: "#0a4050"),
        text: Color(hex: "#839496"),
        textDim: Color(hex: "#586e75"),
        textBright: Color(hex: "#fdf6e3"),
        accent: Color(hex: "#6c71c4"),
        accentDim: Color(hex: "#4e5299"),
        green: Color(hex: "#859900"),
        blue: Color(hex: "#268bd2"),
        orange: Color(hex: "#cb4b16"),
        red: Color(hex: "#dc322f"),
        cyan: Color(hex: "#2aa198"),
        border: Color(hex: "#094959"),
        toolBg: Color(hex: "#012934"),
        thinkingBg: Color(hex: "#012730"),
        extraCss: nil
    )

    static let githubLight = Theme(
        name: .githubLight,
        bg: Color(hex: "#ffffff"),
        bgSurface: Color(hex: "#f6f8fa"),
        bgHover: Color(hex: "#eaeef2"),
        text: Color(hex: "#1f2328"),
        textDim: Color(hex: "#656d76"),
        textBright: Color(hex: "#000000"),
        accent: Color(hex: "#8250df"),
        accentDim: Color(hex: "#6639ba"),
        green: Color(hex: "#1a7f37"),
        blue: Color(hex: "#0969da"),
        orange: Color(hex: "#bc4c00"),
        red: Color(hex: "#cf222e"),
        cyan: Color(hex: "#0598bc"),
        border: Color(hex: "#d0d7de"),
        toolBg: Color(hex: "#f6f8fa"),
        thinkingBg: Color(hex: "#f0f3f6"),
        extraCss: nil
    )

    static let dracula = Theme(
        name: .dracula,
        bg: Color(hex: "#282a36"),
        bgSurface: Color(hex: "#2d2f3d"),
        bgHover: Color(hex: "#383a4a"),
        text: Color(hex: "#f8f8f2"),
        textDim: Color(hex: "#6272a4"),
        textBright: Color(hex: "#ffffff"),
        accent: Color(hex: "#bd93f9"),
        accentDim: Color(hex: "#9571d1"),
        green: Color(hex: "#50fa7b"),
        blue: Color(hex: "#8be9fd"),
        orange: Color(hex: "#ffb86c"),
        red: Color(hex: "#ff5555"),
        cyan: Color(hex: "#8be9fd"),
        border: Color(hex: "#44475a"),
        toolBg: Color(hex: "#21222c"),
        thinkingBg: Color(hex: "#1e1f29"),
        extraCss: nil
    )

    static let bubbles = Theme(
        name: .bubbles,
        bg: Color(hex: "#f0f2f5"),
        bgSurface: Color(hex: "#ffffff"),
        bgHover: Color(hex: "#e4e6eb"),
        text: Color(hex: "#1c1e21"),
        textDim: Color(hex: "#65676b"),
        textBright: Color(hex: "#000000"),
        accent: Color(hex: "#0084ff"),
        accentDim: Color(hex: "#0066cc"),
        green: Color(hex: "#31a24c"),
        blue: Color(hex: "#0084ff"),
        orange: Color(hex: "#f5a623"),
        red: Color(hex: "#e4405f"),
        cyan: Color(hex: "#0097a7"),
        border: Color(hex: "#dddfe2"),
        toolBg: Color(hex: "#e4e6eb"),
        thinkingBg: Color(hex: "#e8daef"),
        extraCss: """
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
    """
    )

    // MARK: - Lookup

    static func named(_ name: ThemeName) -> Theme {
        switch name {
        case .claudeDark: return .claudeDark
        case .claudeLight: return .claudeLight
        case .tokyoNight: return .tokyoNight
        case .monokai: return .monokai
        case .solarizedDark: return .solarizedDark
        case .githubLight: return .githubLight
        case .dracula: return .dracula
        case .bubbles: return .bubbles
        }
    }

    static let `default` = Theme.claudeDark

    static let all: [Theme] = ThemeName.allCases.map { Theme.named($0) }
}
