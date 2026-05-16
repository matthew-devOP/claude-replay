import SwiftUI

// MARK: - ThemeName

/// The closed enum of built-in theme identifiers. Kept in lock-step with the
/// keys in `Resources/themes.json` so the picker UIs can iterate over a
/// strongly-typed list without round-tripping through strings.
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

/// SwiftUI-facing colour model. Values are derived from the underlying
/// `ThemeDict` loaded by `ThemeService` (which is the single source of truth,
/// fed from `Resources/themes.json`). This struct holds no hardcoded palette
/// data of its own.
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

    // MARK: - Lookup

    /// Resolve a built-in theme by its enum identifier. Looks up the colour
    /// values via `ThemeService.getTheme(_:)`, which reads from
    /// `Resources/themes.json` (with a hardcoded fallback for safety).
    static func named(_ name: ThemeName) -> Theme {
        let dict = (try? ThemeService.getTheme(name.rawValue)) ?? [:]
        return Theme(fromDict: dict, name: name)
    }

    /// Build a `Theme` model from a `ThemeDict`. Missing colours fall back to
    /// the tokyo-night defaults so the struct is always fully populated.
    init(fromDict dict: ThemeDict, name: ThemeName) {
        self.name = name
        self.bg = Color(hex: dict["bg"] ?? "#1a1b26")
        self.bgSurface = Color(hex: dict["bg-surface"] ?? "#24253a")
        self.bgHover = Color(hex: dict["bg-hover"] ?? "#2f3147")
        self.text = Color(hex: dict["text"] ?? "#c0caf5")
        self.textDim = Color(hex: dict["text-dim"] ?? "#565f89")
        self.textBright = Color(hex: dict["text-bright"] ?? "#e0e6ff")
        self.accent = Color(hex: dict["accent"] ?? "#bb9af7")
        self.accentDim = Color(hex: dict["accent-dim"] ?? "#7957a8")
        self.green = Color(hex: dict["green"] ?? "#9ece6a")
        self.blue = Color(hex: dict["blue"] ?? "#7aa2f7")
        self.orange = Color(hex: dict["orange"] ?? "#ff9e64")
        self.red = Color(hex: dict["red"] ?? "#f7768e")
        self.cyan = Color(hex: dict["cyan"] ?? "#7dcfff")
        self.border = Color(hex: dict["border"] ?? "#3b3d57")
        self.toolBg = Color(hex: dict["tool-bg"] ?? "#1e1f33")
        self.thinkingBg = Color(hex: dict["thinking-bg"] ?? "#1c1d2e")
        self.extraCss = dict["extraCss"]
    }

    /// Memberwise initialiser kept for any callers that still build a Theme
    /// from explicit colour values (e.g. SwiftUI previews).
    init(
        name: ThemeName,
        bg: Color,
        bgSurface: Color,
        bgHover: Color,
        text: Color,
        textDim: Color,
        textBright: Color,
        accent: Color,
        accentDim: Color,
        green: Color,
        blue: Color,
        orange: Color,
        red: Color,
        cyan: Color,
        border: Color,
        toolBg: Color,
        thinkingBg: Color,
        extraCss: String?
    ) {
        self.name = name
        self.bg = bg
        self.bgSurface = bgSurface
        self.bgHover = bgHover
        self.text = text
        self.textDim = textDim
        self.textBright = textBright
        self.accent = accent
        self.accentDim = accentDim
        self.green = green
        self.blue = blue
        self.orange = orange
        self.red = red
        self.cyan = cyan
        self.border = border
        self.toolBg = toolBg
        self.thinkingBg = thinkingBg
        self.extraCss = extraCss
    }

    /// App-wide default theme. Resolved through `named(_:)` so the colours
    /// come from `themes.json` (or the fallback if the resource is missing).
    static var `default`: Theme { Theme.named(.claudeDark) }

    /// All built-in themes in enum-declaration order.
    static var all: [Theme] { ThemeName.allCases.map { Theme.named($0) } }
}
