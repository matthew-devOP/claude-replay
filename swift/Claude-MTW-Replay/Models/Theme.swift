import SwiftUI

// MARK: - ThemeName

enum ThemeName: String, Codable, CaseIterable, Identifiable, Sendable {
    case tokyoNight = "tokyo-night"
    case monokai
    case solarizedDark = "solarized-dark"
    case githubLight = "github-light"
    case dracula
    case bubbles

    var id: String { rawValue }

    var displayName: String {
        switch self {
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

    var isDark: Bool {
        name != .githubLight
    }

    // MARK: - Built-in Themes

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
        thinkingBg: Color(hex: "#1c1d2e")
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
        thinkingBg: Color(hex: "#22231e")
    )

    static let solarizedDark = Theme(
        name: .solarizedDark,
        bg: Color(hex: "#002b36"),
        bgSurface: Color(hex: "#073642"),
        bgHover: Color(hex: "#0a4050"),
        text: Color(hex: "#839496"),
        textDim: Color(hex: "#586e75"),
        textBright: Color(hex: "#eee8d5"),
        accent: Color(hex: "#6c71c4"),
        accentDim: Color(hex: "#4a4e8a"),
        green: Color(hex: "#859900"),
        blue: Color(hex: "#268bd2"),
        orange: Color(hex: "#cb4b16"),
        red: Color(hex: "#dc322f"),
        cyan: Color(hex: "#2aa198"),
        border: Color(hex: "#094959"),
        toolBg: Color(hex: "#00252e"),
        thinkingBg: Color(hex: "#012731")
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
        cyan: Color(hex: "#0550ae"),
        border: Color(hex: "#d0d7de"),
        toolBg: Color(hex: "#f0f3f6"),
        thinkingBg: Color(hex: "#f6f8fa")
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
        accentDim: Color(hex: "#8b6fc0"),
        green: Color(hex: "#50fa7b"),
        blue: Color(hex: "#8be9fd"),
        orange: Color(hex: "#ffb86c"),
        red: Color(hex: "#ff5555"),
        cyan: Color(hex: "#8be9fd"),
        border: Color(hex: "#44475a"),
        toolBg: Color(hex: "#21222c"),
        thinkingBg: Color(hex: "#232530")
    )

    static let bubbles = Theme(
        name: .bubbles,
        bg: Color(hex: "#1b1d2a"),
        bgSurface: Color(hex: "#252838"),
        bgHover: Color(hex: "#2e3248"),
        text: Color(hex: "#d4daf0"),
        textDim: Color(hex: "#6b7394"),
        textBright: Color(hex: "#eef0ff"),
        accent: Color(hex: "#c49cf8"),
        accentDim: Color(hex: "#8e6bbf"),
        green: Color(hex: "#86e89d"),
        blue: Color(hex: "#7cb3ff"),
        orange: Color(hex: "#ffb074"),
        red: Color(hex: "#ff7a8a"),
        cyan: Color(hex: "#7ee8de"),
        border: Color(hex: "#3a3e55"),
        toolBg: Color(hex: "#181a25"),
        thinkingBg: Color(hex: "#1a1c28")
    )

    // MARK: - Lookup

    static func named(_ name: ThemeName) -> Theme {
        switch name {
        case .tokyoNight: return .tokyoNight
        case .monokai: return .monokai
        case .solarizedDark: return .solarizedDark
        case .githubLight: return .githubLight
        case .dracula: return .dracula
        case .bubbles: return .bubbles
        }
    }

    static let `default` = Theme.tokyoNight

    static let all: [Theme] = ThemeName.allCases.map { Theme.named($0) }
}
