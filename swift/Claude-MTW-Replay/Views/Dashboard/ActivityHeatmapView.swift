import SwiftUI

/// Posted by `ActivityHeatmapView` when the user clicks a cell. The
/// notification's `object` is the `Date` (calendar-day start) the cell
/// represents — listeners (e.g. SessionTableView) can use it to filter
/// their session list. Wiring the filter is out of scope here.
extension Notification.Name {
    static let heatmapDidSelectDate = Notification.Name("heatmapDidSelectDate")
}

/// One cell in the heatmap grid. Carries the calendar-day start so the
/// hover tooltip and click notification both reference the same `Date`.
private struct HeatmapCell: Identifiable, Equatable {
    let id: String                 // "<weekIdx>-<dayIdx>"
    let date: Date
    let sessionCount: Int
    let bucket: Int
}

/// GitHub-style activity heatmap (~26 weeks × 7 days) — same compact
/// shape the web app shows above its sessions table.
///
/// Cell intensity is mapped to a 5-step bucket of session-mtimes per
/// day. Weeks fan left→right, days top→bottom (Mon..Sun).
///
/// P3.9: cells are now interactive — hover shows a date+count tooltip,
/// and click posts `.heatmapDidSelectDate` so downstream views can
/// optionally filter their lists by that day.
struct ActivityHeatmapView: View {
    @Environment(AppState.self) private var appState
    let sessions: [SessionEntry]
    /// Number of trailing weeks to render. 26 keeps the strip compact.
    var weeks: Int = 26

    private static let cellSize: CGFloat = 11
    private static let cellGap: CGFloat = 2

    @State private var hoveredCell: HeatmapCell? = nil

    var body: some View {
        let grid = buildGrid()
        VStack(alignment: .leading, spacing: DesignTokens.space8) {
            HStack(alignment: .top, spacing: Self.cellGap) {
                ForEach(0..<grid.count, id: \.self) { weekIdx in
                    VStack(spacing: Self.cellGap) {
                        ForEach(0..<7, id: \.self) { dayIdx in
                            interactiveCell(grid[weekIdx][dayIdx])
                        }
                    }
                }
            }
            .overlay(alignment: .top) {
                if let hovered = hoveredCell {
                    Text("\(hovered.date.formatted(.dateTime.year().month().day())): \(hovered.sessionCount) session\(hovered.sessionCount == 1 ? "" : "s")")
                        .font(.caption)
                        .padding(.horizontal, DesignTokens.space8)
                        .padding(.vertical, DesignTokens.space4)
                        .appGlass(in: RoundedRectangle(cornerRadius: DesignTokens.cornerSmall))
                        .offset(y: -30)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            HStack(spacing: DesignTokens.space4) {
                Text("Less").font(.caption2).foregroundStyle(.secondary)
                ForEach(0..<5, id: \.self) { i in
                    legendCell(intensity: i)
                }
                Text("More").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    /// One activity cell with hover + tap behaviour. Uses the cell `id` so
    /// fast pointer transits between adjacent cells don't leave a stale
    /// tooltip stuck on the previous square.
    private func interactiveCell(_ cell: HeatmapCell) -> some View {
        Rectangle()
            .fill(color(for: cell.bucket))
            .frame(width: Self.cellSize, height: Self.cellSize)
            .cornerRadius(2)
            .accessibilityLabel("\(cell.date.formatted(.dateTime.year().month().day())): \(cell.sessionCount) sessions")
            .onHover { isHovering in
                if isHovering {
                    hoveredCell = cell
                } else if hoveredCell?.id == cell.id {
                    // Only clear when leaving the *current* tooltip target —
                    // otherwise a late "false" from a previous cell would
                    // dismiss the tooltip the pointer just landed on.
                    hoveredCell = nil
                }
            }
            .onTapGesture {
                NotificationCenter.default.post(
                    name: .heatmapDidSelectDate,
                    object: cell.date
                )
            }
    }

    /// Decorative legend swatch (no hover / tap).
    private func legendCell(intensity: Int) -> some View {
        Rectangle()
            .fill(color(for: intensity))
            .frame(width: Self.cellSize, height: Self.cellSize)
            .cornerRadius(2)
            .accessibilityHidden(true)
    }

    /// Map 0…4 buckets to opacity over the accent color, with 0 being
    /// the surface bg-hover so empty days are visible but quiet.
    private func color(for bucket: Int) -> Color {
        if bucket <= 0 { return appState.theme.bgHover.opacity(0.7) }
        let opacities: [Double] = [0.25, 0.45, 0.7, 1.0]
        let idx = min(opacities.count - 1, max(0, bucket - 1))
        return appState.theme.accent.opacity(opacities[idx])
    }

    /// Build a `weeks × 7` grid of activity buckets ending today. Each
    /// entry carries the calendar-day start `Date` and raw session count
    /// so the hover tooltip + click notification can use them directly.
    private func buildGrid() -> [[HeatmapCell]] {
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

        let placeholder = HeatmapCell(id: "placeholder", date: start, sessionCount: 0, bucket: 0)
        var grid: [[HeatmapCell]] = Array(
            repeating: Array(repeating: placeholder, count: 7),
            count: weeks
        )
        for offset in 0..<totalDays {
            guard let day = cal.date(byAdding: .day, value: offset, to: start) else { continue }
            let weekIdx = offset / 7
            let dayIdx = offset % 7
            let dayStart = cal.startOfDay(for: day)
            let count = counts[dayStart] ?? 0
            grid[weekIdx][dayIdx] = HeatmapCell(
                id: "\(weekIdx)-\(dayIdx)",
                date: dayStart,
                sessionCount: count,
                bucket: bucket(count)
            )
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
