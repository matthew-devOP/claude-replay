import Foundation

/// Resolves (and lazily creates) this app's Application Support directory,
/// namespaced by bundle identifier so we never write into the shared root.
/// Used by local-only persistence such as `Telemetry` and `CrashReporter`.
enum AppSupport {
    /// `~/Library/Application Support/<bundle-id>/`, created on first use.
    /// Falls back to a temp directory if the real one can't be created so
    /// callers never have to handle a nil.
    static func directory() -> URL {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory,
                                in: .userDomainMask,
                                appropriateFor: nil,
                                create: true))
            ?? fm.temporaryDirectory
        let bundleID = Bundle.main.bundleIdentifier ?? "com.claude-replay.Claude-MTW-Replay"
        let dir = base.appendingPathComponent(bundleID, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}
