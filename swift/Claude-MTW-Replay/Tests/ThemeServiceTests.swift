import XCTest
@testable import Claude_MTW_Replay

/// Ported from `test/test-themes.mjs` so the Swift port stays in lock-step
/// with the web reference implementation.
final class ThemeServiceTests: XCTestCase {

    // MARK: - getTheme

    func testGetThemeReturnsBuiltin() throws {
        let theme = try ThemeService.getTheme("dracula")
        XCTAssertEqual(theme["bg"], "#282a36")
        XCTAssertEqual(theme["accent"], "#bd93f9")
    }

    func testGetThemeThrowsOnUnknown() {
        XCTAssertThrowsError(try ThemeService.getTheme("nonexistent")) { error in
            XCTAssertTrue(
                error.localizedDescription.contains("Unknown theme"),
                "Expected 'Unknown theme' in error, got: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - listThemes

    func testListThemesContainsAllBuiltins() {
        let names = ThemeService.listThemes()
        // Themes loaded from Resources/themes.json should include all 8 builtins.
        let expected = [
            "bubbles", "claude-dark", "claude-light", "dracula",
            "github-light", "monokai", "solarized-dark", "tokyo-night",
        ]
        for name in expected {
            XCTAssertTrue(names.contains(name), "expected '\(name)' in listThemes(), got: \(names)")
        }
    }

    // MARK: - themeToCss

    func testThemeToCssGeneratesRootBlock() throws {
        let theme = try ThemeService.getTheme("tokyo-night")
        let css = ThemeService.themeToCss(theme)
        XCTAssertTrue(css.hasPrefix(":root {"), "css should start with :root {, got: \(css.prefix(20))")
        XCTAssertTrue(css.contains("--bg: #1a1b26"), "css should contain --bg: #1a1b26")
        XCTAssertTrue(css.contains("--accent: #bb9af7"), "css should contain --accent: #bb9af7")
        XCTAssertTrue(css.hasSuffix("}") || css.contains("}\n"), "css should end with } (or } followed by extraCss)")
    }

    // MARK: - loadThemeFile

    func testLoadThemeFileMergesWithTokyoNightDefaults() throws {
        let path = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("test-theme-\(UUID().uuidString).json")
        let url = URL(fileURLWithPath: path)
        try ##"{ "bg": "#000000" }"##.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let theme = try ThemeService.loadThemeFile(url)
        XCTAssertEqual(theme["bg"], "#000000", "override should win")
        // Filled from tokyo-night defaults
        XCTAssertEqual(theme["accent"], "#bb9af7", "missing key should fall through to tokyo-night")
    }

    func testLoadThemeFileThrowsOnNonObjectJson() throws {
        let path = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("test-theme-bad-\(UUID().uuidString).json")
        let url = URL(fileURLWithPath: path)
        try #""not an object""#.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try ThemeService.loadThemeFile(url)) { error in
            XCTAssertTrue(
                error.localizedDescription.contains("JSON object"),
                "Expected 'JSON object' in error, got: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Parent inheritance (Swift-side extension over the web tests)

    func testLoadThemeFileHonoursParentField() throws {
        let path = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("test-theme-parent-\(UUID().uuidString).json")
        let url = URL(fileURLWithPath: path)
        // Override one key, inherit the rest from dracula via `parent`.
        let json = ##"{ "parent": "dracula", "colors": { "bg": "#abcdef" } }"##
        try json.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let theme = try ThemeService.loadThemeFile(url)
        XCTAssertEqual(theme["bg"], "#abcdef", "override from `colors` should win")
        XCTAssertEqual(theme["accent"], "#bd93f9", "missing keys should inherit from dracula parent")
        XCTAssertEqual(theme["text"], "#f8f8f2", "missing keys should inherit from dracula parent")
    }
}
