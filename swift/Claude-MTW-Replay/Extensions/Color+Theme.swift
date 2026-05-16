import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch hex.count {
        case 3: (r, g, b, a) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17, 255)
        case 6: (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8: (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b, a) = (0, 0, 0, 255)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }

    /// Returns the sRGB hex string for this color, or `nil` for dynamic /
    /// asset-catalog colors that can't be resolved to a concrete sRGB triple.
    ///
    /// The built-in `Theme` palette uses `Color(hex:)` literals exclusively,
    /// so `toHex()` is expected to return non-nil for all theme colors. The
    /// `assert` below catches accidental regressions in debug builds (e.g.
    /// somebody swaps a hex literal for `.accentColor`) without affecting
    /// the production-release fallback in `ExportViewModel.renderOptions`.
    func toHex() -> String? {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else {
            assert(false, "toHex() returned nil for color — built-in themes must use explicit hex literals")
            return nil
        }
        return String(format: "#%02x%02x%02x", Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
    }
}
