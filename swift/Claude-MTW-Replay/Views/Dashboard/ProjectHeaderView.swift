import SwiftUI

struct ProjectHeaderView: View {
    @Environment(AppState.self) private var appState
    let project: ProjectEntry
    /// Provided by `DashboardView` so the heatmap renders against the
    /// real session list. Optional — falls back to the project's
    /// session-count summary when nil.
    var sessions: [SessionEntry] = []

    private static let dateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    @State private var resolvedPath: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.space8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DesignTokens.space4) {
                    Text(resolvedPath.isEmpty ? project.name : resolvedPath)
                        .font(.title)
                        .bold()
                    Text(project.path)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    HStack(spacing: DesignTokens.space12) {
                        Label("\(project.sessionCount) session\(project.sessionCount == 1 ? "" : "s")",
                              systemImage: "doc.text")
                        if let lastActivity = project.lastActivity {
                            Label(Self.dateFormatter.localizedString(for: lastActivity, relativeTo: Date()),
                                  systemImage: "clock")
                        }
                        if let firstActivity = project.firstActivity, project.firstActivity != project.lastActivity {
                            Text("· created \(Self.dateFormatter.localizedString(for: firstActivity, relativeTo: Date()))")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                quickLaunchers
            }
            if !sessions.isEmpty {
                ActivityHeatmapView(sessions: sessions)
                    .padding(.top, DesignTokens.space4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .task(id: project.dirName) {
            resolvedPath = SessionDiscovery.claudeDirToProjectPath(project.dirName)
        }
    }

    /// Right-side action buttons mirroring the web's [Finder][Terminal]
    /// [LazyGit] cluster — quick launchers for the project directory.
    private var quickLaunchers: some View {
        HStack(spacing: DesignTokens.space6) {
            Button {
                NSWorkspace.shared.open(URL(fileURLWithPath: project.path))
            } label: {
                Label("Finder", systemImage: "folder")
            }
            .controlSize(.small)
            .help("Reveal project in Finder")

            Button {
                NSWorkspace.shared.openTerminal(at: project.path)
            } label: {
                Label("Terminal", systemImage: "terminal")
            }
            .controlSize(.small)
            .help("Open Terminal at project")
        }
    }
}

private extension NSWorkspace {
    /// Open the user's default Terminal app at `path`. Falls back to a
    /// new Finder window if Terminal isn't available.
    func openTerminal(at path: String) {
        let url = URL(fileURLWithPath: path)
        if let term = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
            NSWorkspace.shared.open([url], withApplicationAt: term, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}
