import Foundation
import MetricKit

@MainActor
final class CrashReporter: NSObject {
    static let shared = CrashReporter()
    private var hasStarted = false

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        MXMetricManager.shared.add(self)
    }

    func stop() {
        MXMetricManager.shared.remove(self)
        hasStarted = false
    }

    /// Get latest crash diagnostics for display in Settings (debug only).
    func recentDiagnostics() -> [String] {
        // MetricKit doesn't surface immediately; this returns a summary placeholder.
        return []
    }
}

extension CrashReporter: MXMetricManagerSubscriber {
    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        // Production: persist payloads. For now: log to stderr.
        for payload in payloads {
            print("[CrashReporter] metric payload: \(payload.timeStampBegin)")
        }
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            print("[CrashReporter] diagnostic payload: \(payload.crashDiagnostics?.count ?? 0) crashes, \(payload.hangDiagnostics?.count ?? 0) hangs")
        }
    }
}
