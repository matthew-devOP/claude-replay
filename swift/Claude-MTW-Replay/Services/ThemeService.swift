import Foundation
import SwiftUI

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

// MARK: - Built-in theme definitions (loaded from Resources/themes.json)

/// Minimal fallback in case `themes.json` is missing or fails to decode.
/// Keeps the app rendering with a known dark theme so we never crash.
private let fallbackBuiltinThemes: [String: ThemeDict] = [
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
]

/// Decode `Resources/themes.json` once at first access. The JSON schema is:
///   { "themes": { "<name>": { "<var>": "<hex>", ..., "extraCss": "..." } } }
/// On failure we log a warning and return the minimal hardcoded fallback so
/// the app keeps rendering.
private func loadBuiltinThemesFromJSON() -> [String: ThemeDict] {
    guard let url = Bundle.main.url(forResource: "themes", withExtension: "json") else {
        print("ThemeService: warning — themes.json not found in bundle; using fallback")
        return fallbackBuiltinThemes
    }
    do {
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)
        guard
            let root = object as? [String: Any],
            let themes = root["themes"] as? [String: Any]
        else {
            print("ThemeService: warning — themes.json missing top-level 'themes' object; using fallback")
            return fallbackBuiltinThemes
        }
        var result: [String: ThemeDict] = [:]
        for (name, raw) in themes {
            guard let dict = raw as? [String: String] else { continue }
            result[name] = dict
        }
        if result.isEmpty {
            print("ThemeService: warning — themes.json decoded zero themes; using fallback")
            return fallbackBuiltinThemes
        }
        return result
    } catch {
        print("ThemeService: warning — failed to load themes.json (\(error.localizedDescription)); using fallback")
        return fallbackBuiltinThemes
    }
}

/// Single source of truth for built-in themes, populated lazily from the
/// bundled `themes.json` resource on first access.
private let builtinThemes: [String: ThemeDict] = loadBuiltinThemesFromJSON()

// MARK: - Public API

enum ThemeService {

    /// UserDefaults key for the list of imported custom-theme file paths.
    static let customThemesKey = "customThemes"

    /// In-memory cache of custom themes keyed by their effective name
    /// (filename without extension, or the JSON `name` field if present).
    /// Populated lazily by `reloadFromDisk()` / `loadAllCustomThemes()`.
    nonisolated(unsafe) private static var customCache: [String: ThemeDict] = [:]

    static func getTheme(_ name: String) throws -> ThemeDict {
        if let theme = builtinThemes[name] {
            return theme
        }
        if let custom = customCache[name] {
            return custom
        }
        // Lazy load: maybe the cache is empty because nothing has triggered it yet.
        _ = loadAllCustomThemes()
        if let custom = customCache[name] {
            return custom
        }
        let available = (Array(builtinThemes.keys) + Array(customCache.keys)).sorted().joined(separator: ", ")
        throw NSError(
            domain: "ThemeService",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Unknown theme '\(name)'. Available: \(available)"]
        )
    }

    /// Returns the union of built-in + custom theme names, sorted.
    /// Triggers a (cheap) lazy reload of custom themes on first call.
    static func listThemes() -> [String] {
        if customCache.isEmpty && !customThemePaths().isEmpty {
            _ = loadAllCustomThemes()
        }
        return Array(Set(builtinThemes.keys).union(customCache.keys)).sorted()
    }

    /// Returns just the names of currently-loaded custom themes (sorted).
    /// Useful for UI grouping (e.g. a "Custom" section in the theme picker).
    static func listCustomThemes() -> [String] {
        if customCache.isEmpty && !customThemePaths().isEmpty {
            _ = loadAllCustomThemes()
        }
        return customCache.keys.sorted()
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
        for (name, theme) in customCache {
            var vars: ThemeDict = [:]
            for v in themeVars {
                if let value = theme[v] {
                    vars[v] = value
                }
            }
            if let extra = theme["extraCss"] {
                vars["extraCss"] = extra
            }
            result[name] = vars
        }
        return result
    }

    // MARK: - Custom theme loading

    /// Decodes a JSON theme file at `url` and merges it onto its parent
    /// built-in theme. The JSON may contain:
    ///   - `name`     : optional theme name (defaults to filename w/o ext)
    ///   - `parent`   : optional parent theme (defaults to `tokyo-night`)
    ///   - `colors`   : optional dict of CSS variable overrides
    ///   - `extraCss` : optional extra CSS appended after the `:root` block
    /// For backwards compatibility, a flat `{var: value}` dict is also accepted
    /// (treated as `colors` against the default parent).
    static func loadThemeFile(_ url: URL) throws -> ThemeDict {
        let data = try Data(contentsOf: url)
        // `.fragmentsAllowed` lets us parse non-object JSON (e.g. a bare
        // string) so we can surface our own friendly "must be a JSON object"
        // error instead of Foundation's opaque "couldn't be read" message.
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])

        let parentName: String
        var overrides: [String: String] = [:]
        var extraCss: String?

        if let dict = object as? [String: Any] {
            parentName = (dict["parent"] as? String) ?? "tokyo-night"
            if let colors = dict["colors"] as? [String: String] {
                overrides = colors
            } else {
                // Flat form: every string value is treated as an override.
                for (k, v) in dict where k != "name" && k != "parent" && k != "extraCss" {
                    if let s = v as? String {
                        overrides[k] = s
                    }
                }
            }
            extraCss = dict["extraCss"] as? String
        } else if let flat = object as? [String: String] {
            parentName = "tokyo-night"
            overrides = flat
        } else {
            throw NSError(
                domain: "ThemeService",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Theme file must be a JSON object"]
            )
        }

        let parent = builtinThemes[parentName] ?? builtinThemes["tokyo-night"] ?? [:]
        var merged = parent
        for (key, value) in overrides {
            merged[key] = value
        }
        if let extraCss {
            merged["extraCss"] = extraCss
        }
        return merged
    }

    /// Legacy string-path overload — kept so callers that pass a path keep working.
    static func loadThemeFile(_ filePath: String) throws -> ThemeDict {
        try loadThemeFile(URL(fileURLWithPath: filePath))
    }

    /// Returns the configured theme-file paths persisted in UserDefaults.
    static func customThemePaths() -> [String] {
        UserDefaults.standard.stringArray(forKey: customThemesKey) ?? []
    }

    /// Persists a new list of theme-file paths in UserDefaults.
    static func setCustomThemePaths(_ paths: [String]) {
        UserDefaults.standard.set(paths, forKey: customThemesKey)
    }

    /// Adds a path to the persisted list (dedup) and reloads cache.
    @discardableResult
    static func addCustomThemePath(_ path: String) -> [Theme] {
        var paths = customThemePaths()
        if !paths.contains(path) {
            paths.append(path)
            setCustomThemePaths(paths)
        }
        return loadAllCustomThemes()
    }

    /// Removes a path from the persisted list and reloads cache.
    @discardableResult
    static func removeCustomThemePath(_ path: String) -> [Theme] {
        let paths = customThemePaths().filter { $0 != path }
        setCustomThemePaths(paths)
        return loadAllCustomThemes()
    }

    /// Iterates persisted paths and rebuilds the in-memory custom-theme cache.
    /// Errors on individual files are logged and skipped, so one bad file
    /// doesn't break the whole list. Returns the loaded themes as `Theme`
    /// model instances (using the JSON `name` field or the filename).
    @discardableResult
    static func loadAllCustomThemes() -> [Theme] {
        let paths = customThemePaths()
        var loadedDicts: [String: ThemeDict] = [:]
        var loadedThemes: [Theme] = []

        for path in paths {
            let url = URL(fileURLWithPath: path)
            do {
                let dict = try loadThemeFile(url)
                let name = themeName(forPath: path, url: url)
                loadedDicts[name] = dict
                loadedThemes.append(themeFromDict(name: name, dict: dict))
            } catch {
                print("ThemeService: failed to load custom theme \(path): \(error.localizedDescription)")
            }
        }
        customCache = loadedDicts
        return loadedThemes
    }

    /// Force a fresh re-read of every persisted custom theme from disk.
    /// Equivalent to `loadAllCustomThemes()` but spelled out for clarity
    /// when invoked from a "Reload from disk" button.
    @discardableResult
    static func reloadFromDisk() -> [Theme] {
        loadAllCustomThemes()
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

    // MARK: - Internal helpers

    /// Resolve a custom theme's display name from its JSON (`name` key)
    /// or fall back to the filename without extension.
    private static func themeName(forPath path: String, url: URL) -> String {
        if let data = try? Data(contentsOf: url),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let name = object["name"] as? String,
           !name.isEmpty {
            return name
        }
        return url.deletingPathExtension().lastPathComponent
    }

    /// Build a `Theme` model from a custom dict, using built-in fallbacks
    /// for any missing colour. Used so the SwiftUI side can render the
    /// custom theme even though `ThemeName` is a closed enum.
    private static func themeFromDict(name: String, dict: ThemeDict) -> Theme {
        // We can't add a new case to `ThemeName`; we reuse `.tokyoNight` as
        // the structural placeholder and surface the real name to callers
        // via the parallel `listThemes()`/`getTheme()` string API.
        Theme(
            name: .tokyoNight,
            bg: Color(hex: dict["bg"] ?? "#1a1b26"),
            bgSurface: Color(hex: dict["bg-surface"] ?? "#24253a"),
            bgHover: Color(hex: dict["bg-hover"] ?? "#2f3147"),
            text: Color(hex: dict["text"] ?? "#c0caf5"),
            textDim: Color(hex: dict["text-dim"] ?? "#565f89"),
            textBright: Color(hex: dict["text-bright"] ?? "#e0e6ff"),
            accent: Color(hex: dict["accent"] ?? "#bb9af7"),
            accentDim: Color(hex: dict["accent-dim"] ?? "#7957a8"),
            green: Color(hex: dict["green"] ?? "#9ece6a"),
            blue: Color(hex: dict["blue"] ?? "#7aa2f7"),
            orange: Color(hex: dict["orange"] ?? "#ff9e64"),
            red: Color(hex: dict["red"] ?? "#f7768e"),
            cyan: Color(hex: dict["cyan"] ?? "#7dcfff"),
            border: Color(hex: dict["border"] ?? "#3b3d57"),
            toolBg: Color(hex: dict["tool-bg"] ?? "#1e1f33"),
            thinkingBg: Color(hex: dict["thinking-bg"] ?? "#1c1d2e"),
            extraCss: dict["extraCss"]
        )
    }
}
