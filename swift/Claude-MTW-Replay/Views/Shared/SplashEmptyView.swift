import SwiftUI
import AppKit

/// Rich empty-state / splash view with a mascot, title, subtitle and an
/// optional primary action. Used wherever a tab has nothing to show yet,
/// per P3.6 of `docs/IMPROVEMENTS_SWIFT.md`.
///
/// Falls back to an `sf-symbols` glyph when `Resources/mascot.png` is
/// missing (e.g. in unit tests that don't bundle resources).
struct SplashEmptyView: View {
    var mascotName: String = "mascot"
    let title: String
    let subtitle: String
    var action: ActionSpec? = nil

    struct ActionSpec {
        let label: String
        let run: () -> Void
    }

    var body: some View {
        VStack(spacing: DesignTokens.space16) {
            if let img = NSImage(named: mascotName) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .opacity(0.85)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 80))
                    .foregroundStyle(.tint)
            }
            Text(title)
                .font(.title2)
                .bold()
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let action {
                Button(action.label, action: action.run)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
