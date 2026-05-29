import SwiftUI

/// Shared design constants so radii, spacing, and motion aren't scattered as
/// inline literals. Keep each set small and semantic.
enum DesignTokens {
    // Corner radii
    static let cornerSmall: CGFloat = 6
    static let cornerMedium: CGFloat = 8
    static let cornerLarge: CGFloat = 12

    // Spacing scale — value-preserving steps so every padding/spacing in the
    // app routes through one source. Prefer the semantic aliases below in new
    // code; the numeric steps exist so the existing layout can adopt tokens
    // without shifting by a single point.
    static let space2: CGFloat = 2
    static let space4: CGFloat = 4
    static let space6: CGFloat = 6
    static let space8: CGFloat = 8
    static let space10: CGFloat = 10
    static let space12: CGFloat = 12
    static let space14: CGFloat = 14
    static let space16: CGFloat = 16
    static let space20: CGFloat = 20
    static let space24: CGFloat = 24
    static let space32: CGFloat = 32

    // Semantic aliases (preferred for new code).
    static let spaceXS = space4
    static let spaceSM = space8
    static let spaceMD = space12
    static let spaceLG = space16
    static let spaceXL = space24
}

/// Centralized motion constants so animations share a consistent vocabulary
/// instead of a grab-bag of one-off durations. Route `.animation`/
/// `withAnimation` calls through these.
enum Motion {
    /// Snappy micro-interactions: hover affordances, toggles, small fades.
    static let quick: Animation = .easeInOut(duration: 0.15)
    /// Standard UI transitions: tab switches, content swaps.
    static let standard: Animation = .easeInOut(duration: 0.25)
    /// Emphasized, springy motion: insertions, glass morphs, sheets.
    static let emphasized: Animation = .spring(response: 0.4, dampingFraction: 0.85)
}

extension View {
    /// Apply Apple's Liquid Glass to a floating control when the OS and SDK
    /// support it (macOS 26 "Tahoe"+), falling back to `fallback` (any
    /// `ShapeStyle` — a `Material`, a theme `Color`, …) on macOS 15/14 so
    /// the existing look is preserved exactly below the glass era. This is
    /// the single funnel for glass in the app so adoption stays tunable in
    /// one place.
    ///
    /// `interactive` opts into the glass variant that responds to press/hover
    /// with a light reaction — use it for tappable controls.
    ///
    /// Compile-time guarded with `#if compiler(>=6.2)` so the project still
    /// builds on Xcode 16 (whose SDK lacks `glassEffect`); runtime guarded
    /// with `#available` so one binary runs on macOS 14 → 26.
    @ViewBuilder
    func appGlass<S: Shape, F: ShapeStyle>(in shape: S, fallback: F, interactive: Bool = false) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            self.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            self.background(fallback, in: shape)
        }
        #else
        self.background(fallback, in: shape)
        #endif
    }

    /// Glass with the default `.regularMaterial` fallback.
    func appGlass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        appGlass(in: shape, fallback: .regularMaterial, interactive: interactive)
    }

    /// Convenience for the common rounded-rectangle case.
    func appGlass<F: ShapeStyle>(cornerRadius: CGFloat, fallback: F, interactive: Bool = false) -> some View {
        appGlass(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), fallback: fallback, interactive: interactive)
    }

    func appGlass(cornerRadius: CGFloat, interactive: Bool = false) -> some View {
        appGlass(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), fallback: .regularMaterial, interactive: interactive)
    }

    /// Assign a glass identity so a control morphs smoothly to/from sibling
    /// glass shapes inside a `glassGroup`. No-op below macOS 26.
    @ViewBuilder
    func appGlassID(_ id: some Hashable & Sendable, in namespace: Namespace.ID) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            self.glassEffectID(id, in: namespace)
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// Wrap a cluster of glass controls in a `GlassEffectContainer` so their
    /// shapes blend/merge correctly when near each other. Passes the content
    /// straight through on older OS/SDK.
    @ViewBuilder
    func glassGroup(spacing: CGFloat = 8) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { self }
        } else {
            self
        }
        #else
        self
        #endif
    }
}
