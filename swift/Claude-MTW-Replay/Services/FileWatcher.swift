import Foundation

/// Watches a directory (or file) for changes using GCD's `DispatchSource`
/// and fires a callback when modifications are detected.  Used for live
/// detection of new session files.
final class FileWatcher {

    /// Events the watcher can report.
    enum Event {
        case modified      // file content changed
        case created       // new file appeared in directory
        case deleted       // file or directory was removed
        case renamed       // file was renamed
    }

    typealias Handler = (_ url: URL, _ event: Event) -> Void

    // MARK: - State

    private let url: URL
    private let handler: Handler
    private let queue: DispatchQueue
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1

    /// Snapshot of directory contents used to diff on change.
    private var lastKnownContents: Set<String> = []

    // MARK: - Init

    /// - Parameters:
    ///   - url: Path to watch (file or directory).
    ///   - queue: Queue on which the handler fires.  Defaults to a
    ///     dedicated serial queue.
    ///   - handler: Closure invoked when a change is detected.
    init(url: URL,
         queue: DispatchQueue = DispatchQueue(label: "com.claude-replay.filewatcher", qos: .utility),
         handler: @escaping Handler) {
        self.url = url
        self.queue = queue
        self.handler = handler
    }

    deinit {
        stop()
    }

    // MARK: - Public API

    /// Begin watching.  Safe to call multiple times (stops the previous
    /// watcher first).
    func start() {
        stop()

        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("[FileWatcher] Unable to open \(url.path)")
            return
        }

        // Snapshot current directory contents for diffing later
        snapshotDirectoryContents()

        let mask: DispatchSource.FileSystemEvent = [.write, .delete, .rename, .extend]
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: mask,
            queue: queue
        )

        src.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = src.data
            if flags.contains(.delete) {
                self.handler(self.url, .deleted)
                // Re-watch — the file may reappear
                self.restart()
            } else if flags.contains(.rename) {
                self.handler(self.url, .renamed)
                self.restart()
            } else if flags.contains(.write) || flags.contains(.extend) {
                self.detectChanges()
            }
        }

        src.setCancelHandler { [fd = fileDescriptor] in
            close(fd)
        }

        source = src
        src.resume()
    }

    /// Stop watching and release the file descriptor.
    func stop() {
        source?.cancel()
        source = nil
        fileDescriptor = -1
    }

    // MARK: - Internals

    private func restart() {
        // Brief delay before re-opening — give the filesystem time to settle.
        queue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.start()
        }
    }

    /// Compare current directory listing against the last snapshot to
    /// detect new files.
    private func detectChanges() {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return }

        if isDir.boolValue {
            // Directory mode — diff contents
            let current = Set((try? fm.contentsOfDirectory(atPath: url.path)) ?? [])
            let added = current.subtracting(lastKnownContents)
            let removed = lastKnownContents.subtracting(current)
            lastKnownContents = current

            for name in added {
                handler(url.appendingPathComponent(name), .created)
            }
            for name in removed {
                handler(url.appendingPathComponent(name), .deleted)
            }
            // If nothing was added/removed but we got a write event,
            // treat it as a generic modification.
            if added.isEmpty && removed.isEmpty {
                handler(url, .modified)
            }
        } else {
            handler(url, .modified)
        }
    }

    private func snapshotDirectoryContents() {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
           isDir.boolValue {
            lastKnownContents = Set(
                (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
            )
        }
    }
}

// MARK: - Multi-directory convenience

extension FileWatcher {

    /// Watch multiple session root directories and their immediate
    /// subdirectories so that new sessions within existing projects are
    /// detected, not just new project directories.
    static func watchSessionDirectories(
        handler: @escaping Handler
    ) -> [FileWatcher] {
        watchSessionDirectories(claudeAccountDirs: [".claude"], handler: handler)
    }

    /// Watch session roots for a specific set of Claude accounts, plus the
    /// global Cursor/Codex roots once. Used by the ALL-accounts view (and any
    /// non-default single account) so new sessions in every watched account
    /// flow back into the UI — not just `~/.claude`.
    static func watchSessionDirectories(
        claudeAccountDirs: [String],
        handler: @escaping Handler
    ) -> [FileWatcher] {
        let fm = FileManager.default
        var roots: [URL] = claudeAccountDirs.map {
            fm.homeDirectoryURL.appendingPathComponent($0).appendingPathComponent("projects")
        }
        roots.append(fm.homeDirectoryURL.appendingPathComponent(".cursor/projects"))
        roots.append(fm.homeDirectoryURL.appendingPathComponent(".codex/sessions"))
        var watchers: [FileWatcher] = []

        for rootURL in roots {
            guard fm.isDirectory(at: rootURL.path) else { continue }

            // Watch the root directory itself (detects new project dirs)
            let rootWatcher = FileWatcher(url: rootURL, handler: handler)
            rootWatcher.start()
            watchers.append(rootWatcher)

            // Also watch each project subdirectory (detects new session files)
            for subdir in fm.sortedSubdirectories(at: rootURL) {
                let subdirURL = rootURL.appendingPathComponent(subdir)
                let subWatcher = FileWatcher(url: subdirURL, handler: handler)
                subWatcher.start()
                watchers.append(subWatcher)
            }
        }

        return watchers
    }
}
