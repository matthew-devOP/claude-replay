import SwiftUI

/// Lists `*.md` plans saved by Claude Code under
/// `~/.claude/plans/<project-encoded-dir>/` and renders the selected one
/// with `MarkdownTextView`.
///
/// Plan files are written by the `Plan` agent slash-command and are the
/// macOS app's equivalent of the web's "Plans" project tab.
struct PlansListView: View {
    @Environment(AppState.self) private var appState
    let projectPath: String

    @State private var plans: [PlanFile] = []
    @State private var selectedPlan: PlanFile?
    @State private var loadError: String?

    struct PlanFile: Identifiable, Hashable {
        let url: URL
        let modified: Date
        var id: String { url.path }
        var name: String { url.deletingPathExtension().lastPathComponent }
    }

    var body: some View {
        HSplitView {
            // Left: list of plan files
            VStack(alignment: .leading, spacing: 0) {
                Text("Plans")
                    .font(.caption.smallCaps())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DesignTokens.space12)
                    .padding(.vertical, DesignTokens.space8)
                Divider()
                if let err = loadError {
                    Text(err).font(.caption).foregroundStyle(.red).padding()
                } else if plans.isEmpty {
                    Text("No plans saved for this project yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    List(selection: $selectedPlan) {
                        ForEach(plans) { plan in
                            VStack(alignment: .leading, spacing: DesignTokens.space2) {
                                Text(plan.name)
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(plan.modified.shortRelativeString())
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(plan)
                        }
                    }
                    .listStyle(.sidebar)
                }
            }
            .frame(minWidth: 220, idealWidth: 260)

            // Right: selected plan content
            Group {
                if let plan = selectedPlan,
                   let content = (try? String(contentsOf: plan.url, encoding: .utf8)) {
                    ScrollView {
                        MarkdownTextView(markdown: content)
                            .padding(DesignTokens.space20)
                    }
                } else {
                    EmptyStateView(
                        icon: "doc.text.below.ecg",
                        title: "Select a plan",
                        subtitle: "Plans the planner saved for this project appear in the list."
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(appState.theme.bg)
        }
        .task(id: projectPath) { loadPlans() }
    }

    /// Plans live under `~/.claude/plans/<encoded-dir>/`. The encoded dir
    /// follows the same `-` substitution Claude Code uses for project IDs,
    /// so we derive it from the project's filesystem path. We also probe
    /// the legacy `~/.claude/plans/` flat directory for older installs.
    private func loadPlans() {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let baseUrls = [
            home.appendingPathComponent(".claude/plans/" + encodedDir(projectPath)),
            home.appendingPathComponent(".claude/plans"),
        ]
        var found: [PlanFile] = []
        for base in baseUrls where fm.fileExists(atPath: base.path) {
            if let entries = try? fm.contentsOfDirectory(
                at: base,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) {
                for url in entries where url.pathExtension.lowercased() == "md" {
                    let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    found.append(PlanFile(url: url, modified: modified))
                }
            }
        }
        plans = found.sorted { $0.modified > $1.modified }
        if selectedPlan == nil { selectedPlan = plans.first }
    }

    /// Reproduce Claude Code's project-dir encoding: `/Users/foo/bar` → `-Users-foo-bar`.
    private func encodedDir(_ path: String) -> String {
        let stripped = path.replacingOccurrences(of: "/", with: "-")
        return stripped.hasPrefix("-") ? stripped : "-" + stripped
    }
}
