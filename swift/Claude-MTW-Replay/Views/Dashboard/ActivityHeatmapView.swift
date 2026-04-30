import SwiftUI

/// GitHub-style activity heatmap (~52 weeks × 7 days) — same compact
/// shape the web app shows above its sessions table.
///
/// Cell intensity is mapped to a 5-step bucket of session-mtimes per
/// day. Weeks fan left→right, days top→bottom (Mon..Sun).
struct ActivityHeatmapView: View {
    @Environment(AppState.self) private var appState
    let sessions: [SessionEntry]
    /// Number of trailing weeks to render. 26 keeps the strip compact.
    var weeks: Int = 26

    private static let cellSize: CGFloat = 11
    private static let cellGap: CGFloat = 2

    var body: some View {
        let grid = buildGrid()
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: Self.cellGap) {
                ForEach(0..<grid.count, id: \.self) { weekIdx in
                    VStack(spacing: Self.cellGap) {
                        ForEach(0..<7, id: \.self) { dayIdx in
                            cell(intensity: grid[weekIdx][dayIdx])
                        }
                    }
                }
            }
            HStack(spacing: 4) {
                Text("Less").font(.caption2).foregroundStyle(.secondary)
                ForEach(0..<5, id: \.self) { i in
                    cell(intensity: i)
                }
                Text("More").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func cell(intensity: Int) -> some View {
        Rectangle()
            .fill(color(for: intensity))
            .frame(width: Self.cellSize, height: Self.cellSize)
            .cornerRadius(2)
    }

    /// Map 0…4 buckets to opacity over the accent color, with 0 being
    /// the surface bg-hover so empty days are visible but quiet.
    private func color(for bucket: Int) -> Color {
        if bucket <= 0 { return appState.theme.bgHover.opacity(0.7) }
        let opacities: [Double] = [0.25, 0.45, 0.7, 1.0]
        let idx = min(opacities.count - 1, max(0, bucket - 1))
        return appState.theme.accent.opacity(opacities[idx])
    }

    /// Build a `weeks × 7` grid of activity buckets ending today.
    private func buildGrid() -> [[Int]] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // Count session dates per day.
        var counts: [Date: Int] = [:]
        for session in sessions {
            guard let d = session.date else { continue }
            let day = cal.startOfDay(for: d)
            counts[day, default: 0] += 1
        }
        // Compute the start day = `today - (weeks*7 - 1)` days, snapped
        // to the same weekday position so the columns line up.
        let totalDays = weeks * 7
        let start = cal.date(byAdding: .day, value: -(totalDays - 1), to: today)!

        var grid: [[Int]] = Array(repeating: Array(repeating: 0, count: 7), count: weeks)
        for offset in 0..<totalDays {
            guard let day = cal.date(byAdding: .day, value: offset, to: start) else { continue }
            let weekIdx = offset / 7
            let dayIdx = offset % 7
            let count = counts[cal.startOfDay(for: day)] ?? 0
            grid[weekIdx][dayIdx] = bucket(count)
        }
        return grid
    }

    private func bucket(_ count: Int) -> Int {
        switch count {
        case 0:     return 0
        case 1:     return 1
        case 2:     return 2
        case 3...4: return 3
        default:    return 4
        }
    }
}
