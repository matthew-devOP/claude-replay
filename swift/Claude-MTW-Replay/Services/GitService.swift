import Foundation

struct GitInfo {
    let branch: String?
    let remotes: [String]
    let status: GitStatus
}
struct GitStatus {
    let modified: Int; let added: Int; let deleted: Int
    var isClean: Bool { modified == 0 && added == 0 && deleted == 0 }
}
struct GitDetails {
    let commitCount: Int
    let recentCommits: [GitCommit]
    let graph: String
}
struct GitCommit: Identifiable {
    let id: String // hash
    let hash: String; let message: String; let author: String; let date: String
}

enum GitService {
    static func gitExec(cwd: URL, args: [String]) async -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        proc.arguments = args
        proc.currentDirectoryURL = cwd
        let pipe = Pipe()
        proc.standardOutput = pipe; proc.standardError = Pipe()
        do {
            try proc.run()
            let status = await withCheckedContinuation { continuation in
                proc.terminationHandler = { process in
                    continuation.resume(returning: process.terminationStatus)
                }
            }
            guard status == 0 else { return nil }
            return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch { return nil }
    }

    static func getGitInfo(projectPath: URL) async -> GitInfo? {
        guard let branch = await gitExec(cwd: projectPath, args: ["rev-parse", "--abbrev-ref", "HEAD"]) else { return nil }
        let remotesStr = await gitExec(cwd: projectPath, args: ["remote"]) ?? ""
        let remotes = remotesStr.split(separator: "\n").map(String.init)
        let statusStr = await gitExec(cwd: projectPath, args: ["status", "--porcelain"]) ?? ""
        let lines = statusStr.split(separator: "\n")
        let modified = lines.filter { $0.hasPrefix(" M") || $0.hasPrefix("M ") }.count
        let added = lines.filter { $0.hasPrefix("A ") || $0.hasPrefix("??") }.count
        let deleted = lines.filter { $0.hasPrefix(" D") || $0.hasPrefix("D ") }.count
        return GitInfo(branch: branch, remotes: remotes, status: GitStatus(modified: modified, added: added, deleted: deleted))
    }

    static func getGitDetails(projectPath: URL) async -> GitDetails? {
        guard let countStr = await gitExec(cwd: projectPath, args: ["rev-list", "--count", "HEAD"]),
              let count = Int(countStr) else { return nil }
        let logStr = await gitExec(cwd: projectPath, args: ["log", "--oneline", "--format=%H%x1f%s%x1f%an%x1f%ad", "--date=relative", "-30"]) ?? ""
        let commits = logStr.split(separator: "\n").compactMap { line -> GitCommit? in
            let parts = line.split(separator: "\u{1f}", maxSplits: 3).map(String.init)
            guard parts.count >= 4 else { return nil }
            return GitCommit(id: parts[0], hash: String(parts[0].prefix(8)), message: parts[1], author: parts[2], date: parts[3])
        }
        let graph = await gitExec(cwd: projectPath, args: ["log", "--graph", "--oneline", "--all", "-50"]) ?? ""
        return GitDetails(commitCount: count, recentCommits: commits, graph: graph)
    }
}
