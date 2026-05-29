import SwiftUI

/// Status hint that lets a caller scope the spinner to a subset of verbs
/// matching what the app is currently doing. Falls back to the full
/// `SpinnerVerbs.list` for `.idle` / unset callers (the toolbar default).
enum SpinnerStatus {
    case idle
    case loading
    case parsing
    case indexing
    case composing
    case tooling
    case thinking
}

/// Shimmering "✦ Verbing…" widget for the toolbar.
///
/// Mirrors the web v0.7.3 header spinner: a star, a verb that cycles through
/// `SpinnerVerbs.list` every 2.4 s, and a reverse-sweep glimmer band that
/// travels right→left across the verb (theme-aware via AppState.theme).
///
/// The glimmer is built with a `LinearGradient` whose stops are recomputed
/// each frame inside a `TimelineView(.animation)` — no stored state, no
/// implicit animation needed.
///
/// P3.7: `status` narrows the verb pool so the widget reads as semantic.
/// Default `.idle` keeps the original full-vocabulary behaviour.
struct SpinnerVerbView: View {
    @Environment(AppState.self) private var appState
    var status: SpinnerStatus = .idle
    @State private var verbIndex: Int = 0

    /// Shimmer/star pulse period — matches the web CSS keyframes.
    private static let cycleSeconds: Double = 2.4

    /// Verb pool filtered by the requested status. `.idle` keeps the full
    /// playful set; the others scope down to a small handful of
    /// situationally-appropriate words.
    private var verbsForStatus: [String] {
        switch status {
        case .loading:   return ["Resolving", "Parsing", "Indexing", "Loading"]
        case .parsing:   return ["Parsing", "Decoding", "Reading"]
        case .indexing:  return ["Indexing", "Hashing", "Stamping"]
        case .composing: return ["Composing", "Drafting", "Writing", "Reasoning"]
        case .tooling:   return ["Tooling", "Executing", "Calling", "Running"]
        case .thinking:  return ["Thinking", "Pondering", "Considering"]
        case .idle:      return SpinnerVerbs.list
        }
    }

    var body: some View {
        let verbs = verbsForStatus
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate
            let shimmerPhase = (elapsed / Self.cycleSeconds).truncatingRemainder(dividingBy: 1.0)
            // Star pulse: 0…1…0 over one cycle (sine, eased)
            let starWave = sin(shimmerPhase * 2 * .pi - .pi / 2) * 0.5 + 0.5
            let starOpacity = 0.65 + 0.35 * starWave
            let starScale = 1.0 + 0.12 * starWave

            HStack(spacing: DesignTokens.space6) {
                Text("\u{2726}") // ✦
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(appState.theme.accent)
                    .opacity(starOpacity)
                    .scaleEffect(starScale)

                Text(verbs[min(verbIndex, max(0, verbs.count - 1))])
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(shimmerGradient(phase: shimmerPhase))

                Text("\u{2026}") // …
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(appState.theme.textDim)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .onAppear {
            // Pick a random starting verb within the current status pool so
            // back-to-back appearances don't always begin on the same word.
            if !verbs.isEmpty {
                verbIndex = Int.random(in: 0..<verbs.count)
            }
        }
        .task(id: status) {
            // Reset to a fresh random verb whenever the status changes —
            // keeps the visible word in sync with the new vocabulary.
            let pool = verbsForStatus
            if !pool.isEmpty {
                verbIndex = Int.random(in: 0..<pool.count)
            }
            // Swap verb each cycle. Cancels automatically when the view
            // disappears or `status` changes (task is keyed on status).
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(Int(Self.cycleSeconds * 1000)))
                guard !Task.isCancelled else { return }
                let pool = verbsForStatus
                guard !pool.isEmpty else { continue }
                verbIndex = (verbIndex + 1) % pool.count
            }
        }
    }

    /// Build a gradient that places a bright band at fraction `bandCenter`
    /// (which sweeps from 1.2 → -0.2 across the cycle), padded by `dim` on
    /// either side. Stops are clamped to [0, 1] and the band degenerates to a
    /// flat dim gradient when fully off-screen.
    private func shimmerGradient(phase: Double) -> LinearGradient {
        let dim = appState.theme.textDim
        let bright = appState.theme.textBright
        let bandCenter = 1.2 - phase * 1.4
        let bandHalf = 0.15

        let stops: [Gradient.Stop]
        if bandCenter + bandHalf <= 0 || bandCenter - bandHalf >= 1 {
            stops = [
                .init(color: dim, location: 0),
                .init(color: dim, location: 1),
            ]
        } else {
            let s1 = max(0, bandCenter - bandHalf)
            let s2 = max(0, min(1, bandCenter))
            let s3 = min(1, bandCenter + bandHalf)
            stops = [
                .init(color: dim, location: 0),
                .init(color: dim, location: s1),
                .init(color: bright, location: s2),
                .init(color: dim, location: s3),
                .init(color: dim, location: 1),
            ]
        }
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
    }
}
