import AppKit
import UniformTypeIdentifiers

extension Notification.Name {
    static let didReceiveDroppedSession = Notification.Name("didReceiveDroppedSession")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor let statusItemController = StatusItemController()

    func application(_ application: NSApplication, open urls: [URL]) {
        let jsonlFiles = urls.filter { $0.pathExtension == "jsonl" }
        guard !jsonlFiles.isEmpty else { return }
        NotificationCenter.default.post(name: .didReceiveDroppedSession, object: nil, userInfo: ["urls": jsonlFiles])
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            statusItemController.install()
            CrashReporter.shared.start()
            Telemetry.shared.record(.appLaunched)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            statusItemController.uninstall()
        }
    }
}
