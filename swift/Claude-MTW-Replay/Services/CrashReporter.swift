import Foundation
import MetricKit

/// Subscribes to MetricKit and persists crash/hang diagnostic summaries to a
/// local JSONL log so Settings can surface "recent diagnostics". MetricKit
/// delivers payloads at most once per day (and on next launch after a crash),
/// so this is a slow-filling, on-disk record — nothing is sent anywhere.
@MainActor
final class CrashReporter: NSObject {
    static let shared = CrashReporter()
    private var hasStarted = false

    /// One persisted diagnostic summary line.
    struct Summary: Codable, Hashable {
        let date: Date
        let crashes: Int
        let hangs: Int
        let cpuExceptions: Int
        let diskWrites: Int
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        MXMetricManager.shared.add(self)
    }

    func stop() {
        MXMetricManager.shared.remove(self)
        hasStarted = false
    }

    /// Recent diagnostic summaries (newest first) for display in Settings.
    func recentDiagnostics() -> [String] {
        guard let data = try? Data(contentsOf: Self.storeURL) else { return [] }
        let decoder = JSONDecoder()
        let summaries = data.split(separator: 0x0a).compactMap { line -> Summary? in
            try? decoder.decode(Summary.self, from: Data(line))
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return summaries.suffix(50).reversed().map { s in
            "\(formatter.string(from: s.date)) — \(s.crashes) crash(es), \(s.hangs) hang(s), \(s.cpuExceptions) CPU exception(s)"
        }
    }

    // MARK: - Local persistence

    nonisolated static var storeURL: URL {
        AppSupport.directory().appendingPathComponent("diagnostics.jsonl")
    }

    /// Append a summary line. `nonisolated` + static so the off-main
    /// MetricKit callbacks can call it without hopping to the main actor.
    nonisolated static func persist(_ summary: Summary) {
        guard let line = try? JSONEncoder().encode(summary) else { return }
        let data = line + Data([0x0a])
        if let handle = try? FileHandle(forWritingTo: storeURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: storeURL, options: .atomic)
        }
    }
}

extension CrashReporter: MXMetricManagerSubscriber {
    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        // Aggregate metric payloads aren't crash data; we only persist the
        // diagnostic payloads below. Metric payloads are intentionally ignored.
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            let summary = CrashReporter.Summary(
                date: payload.timeStampEnd,
                crashes: payload.crashDiagnostics?.count ?? 0,
                hangs: payload.hangDiagnostics?.count ?? 0,
                cpuExceptions: payload.cpuExceptionDiagnostics?.count ?? 0,
                diskWrites: payload.diskWriteExceptionDiagnostics?.count ?? 0
            )
            CrashReporter.persist(summary)
        }
    }
}
