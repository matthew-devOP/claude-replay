import AppKit
import UniformTypeIdentifiers

extension Notification.Name {
    static let didReceiveDroppedSession = Notification.Name("didReceiveDroppedSession")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        let jsonlFiles = urls.filter { $0.pathExtension == "jsonl" }
        guard !jsonlFiles.isEmpty else { return }
        NotificationCenter.default.post(name: .didReceiveDroppedSession, object: nil, userInfo: ["urls": jsonlFiles])
    }
}
