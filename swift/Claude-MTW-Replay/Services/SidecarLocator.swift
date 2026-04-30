import Foundation

/// Resolves the absolute paths of the helpers the Chats tab needs:
///   • the bundled Node sidecar (`Sidecar/sidecar.js` inside the .app)
///   • the `node` binary on the host
///   • the `claude` binary on the host
///
/// The sidecar lives inside the .app bundle (copied there by the
/// `Copy sidecar bundle` Run Script build phase). For `node` and
/// `claude` we don't bundle anything — we look them up on the host
/// the same way the user would, then cache the resolved paths in
/// UserDefaults so subsequent launches don't pay the lookup cost.
///
/// All resolutions are deliberately resilient: a missing binary
/// surfaces as a typed error so the UI can offer a "Locate manually"
/// picker rather than crashing.
enum SidecarLocator {

    // MARK: - Errors

    enum LocateError: LocalizedError {
        case sidecarMissing(URL)
        case nodeMissing
        case claudeMissing

        var errorDescription: String? {
            switch self {
            case .sidecarMissing(let url):
                return "Sidecar bundle missing at \(url.path). Run swift/sidecar/build.sh and rebuild the app."
            case .nodeMissing:
                return "Node.js not found. Install with `brew install node` or use Settings → Locate node."
            case .claudeMissing:
                return "Claude Code CLI not found. Install from claude.ai/code or use Settings → Locate claude."
            }
        }
    }

    // MARK: - Public API

    /// Absolute URL of the bundled `sidecar.js` (inside .app/Contents/Resources/Sidecar/).
    static func bundledSidecarScript() throws -> URL {
        guard let resources = Bundle.main.resourceURL else {
            throw LocateError.sidecarMissing(URL(fileURLWithPath: "<no resourceURL>"))
        }
        let url = resources.appendingPathComponent("Sidecar/sidecar.js")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LocateError.sidecarMissing(url)
        }
        return url
    }

    /// Absolute URL of the `node` binary, cached in UserDefaults.
    static func nodeBinary() throws -> URL {
        if let cached = cachedURL(forKey: nodeKey) { return cached }
        if let url = findBinary(name: "node", commonPaths: nodeCandidatePaths) {
            persist(url: url, forKey: nodeKey)
            return url
        }
        throw LocateError.nodeMissing
    }

    /// Absolute URL of the `claude` binary, cached in UserDefaults.
    static func claudeBinary() throws -> URL {
        if let cached = cachedURL(forKey: claudeKey) { return cached }
        if let url = findBinary(name: "claude", commonPaths: claudeCandidatePaths) {
            persist(url: url, forKey: claudeKey)
            return url
        }
        throw LocateError.claudeMissing
    }

    /// User overrides from Settings → Locate manually.
    static func setNodeBinary(_ url: URL) { persist(url: url, forKey: nodeKey) }
    static func setClaudeBinary(_ url: URL) { persist(url: url, forKey: claudeKey) }

    // MARK: - Implementation

    private static let nodeKey   = "sidecarLocator.node"
    private static let claudeKey = "sidecarLocator.claude"

    /// Common install paths checked before falling back to a login-shell `which`.
    private static let nodeCandidatePaths = [
        "/opt/homebrew/bin/node",
        "/usr/local/bin/node",
        "/usr/bin/node",
    ]

    private static let claudeCandidatePaths = [
        "/opt/homebrew/bin/claude",
        "/usr/local/bin/claude",
        "/usr/bin/claude",
        // Per-user installs from `claude install` land here.
        "\(NSHomeDirectory())/.local/bin/claude",
        "\(NSHomeDirectory())/.claude/local/claude",
    ]

    private static func cachedURL(forKey key: String) -> URL? {
        guard let path = UserDefaults.standard.string(forKey: key) else { return nil }
        let url = URL(fileURLWithPath: path)
        // Re-verify each launch — installs move (e.g. brew upgrade).
        return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
    }

    private static func persist(url: URL, forKey key: String) {
        UserDefaults.standard.set(url.path, forKey: key)
    }

    private static func findBinary(name: String, commonPaths: [String]) -> URL? {
        let fm = FileManager.default
        for path in commonPaths where fm.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        // Fall back to a login shell so we pick up custom install dirs
        // (asdf, fnm, volta, etc.) without us having to know about each one.
        return whichViaLoginShell(name)
    }

    /// Run `zsh -lc 'which <name>'` to inherit the user's PATH from their shell rc.
    private static func whichViaLoginShell(_ name: String) -> URL? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-lc", "command -v \(name)"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
            guard proc.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) else { return nil }
            return URL(fileURLWithPath: path)
        } catch {
            return nil
        }
    }
}
