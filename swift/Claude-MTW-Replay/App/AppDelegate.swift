import AppKit
import UniformTypeIdentifiers

extension Notification.Name {
    static let didReceiveDroppedSession = Notification.Name("didReceiveDroppedSession")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor let statusItemController = StatusItemController()
    private var recentSessionObserver: NSObjectProtocol?

    func application(_ application: NSApplication, open urls: [URL]) {
        let jsonlFiles = urls.filter { $0.pathExtension == "jsonl" }
        guard !jsonlFiles.isEmpty else { return }
        NotificationCenter.default.post(name: .didReceiveDroppedSession, object: nil, userInfo: ["urls": jsonlFiles])
    }

    /// Persist a session URL to the `Open Recent` store. Safe to call from
    /// any thread; the underlying store is `@MainActor`.
    func addRecentSessionURL(_ url: URL) {
        let path = url.path
        Task { @MainActor in
            RecentSessionsStore.shared.add(path: path)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            statusItemController.install()
            CrashReporter.shared.start()
            Telemetry.shared.record(.appLaunched)
        }
        recentSessionObserver = NotificationCenter.default.addObserver(forName: .sessionSelected, object: nil, queue: .main) { notif in
            let info = notif.userInfo ?? [:]
            guard let path = info["path"] as? String, !path.isEmpty else { return }
            Task { @MainActor in
                RecentSessionsStore.shared.add(path: path)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            statusItemController.uninstall()
        }
    }
}
