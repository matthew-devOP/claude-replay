import Foundation
import SwiftUI

/// Opt-in, **local-only** usage telemetry. There is no remote endpoint by
/// design — this is a privacy-respecting desktop app, so events are appended
/// to a JSONL file under Application Support and surfaced back in Settings.
/// Nothing ever leaves the machine. If a real backend is ever added it would
/// drain this same on-disk queue.
@MainActor
final class Telemetry {
    static let shared = Telemetry()

    @AppStorage("telemetryOptIn") private var optedIn: Bool = false
    @AppStorage("telemetryAnonymousId") private var anonymousId: String = ""

    enum Event {
        case appLaunched
        case tabSwitched(tab: String)
        case chatStarted
        case exportClicked(format: String)
        case sessionImported

        var name: String {
            switch self {
            case .appLaunched: return "app_launched"
            case .tabSwitched: return "tab_switched"
            case .chatStarted: return "chat_started"
            case .exportClicked: return "export_clicked"
            case .sessionImported: return "session_imported"
            }
        }

        /// Event-specific properties recorded alongside the name.
        var properties: [String: String] {
            switch self {
            case .tabSwitched(let tab): return ["tab": tab]
            case .exportClicked(let format): return ["format": format]
            case .appLaunched, .chatStarted, .sessionImported: return [:]
            }
        }
    }

    /// One persisted telemetry record.
    struct Record: Codable, Hashable {
        let name: String
        let properties: [String: String]
        let timestamp: Date
    }

    func record(_ event: Event) {
        guard optedIn else { return }
        if anonymousId.isEmpty {
            anonymousId = UUID().uuidString
        }
        let record = Record(name: event.name, properties: event.properties, timestamp: Date())
        appendLocal(record)
    }

    /// Most recent records (newest first), capped, for display in Settings.
    func recentEvents(limit: Int = 100) -> [Record] {
        guard let data = try? Data(contentsOf: Self.storeURL) else { return [] }
        let decoder = JSONDecoder()
        let records = data.split(separator: 0x0a).compactMap { line -> Record? in
            try? decoder.decode(Record.self, from: Data(line))
        }
        return Array(records.suffix(limit).reversed())
    }

    /// Erase the local event log (Settings → "Clear telemetry data").
    func clear() {
        try? FileManager.default.removeItem(at: Self.storeURL)
    }

    /// Public for UI to read & set.
    var isOptedIn: Bool {
        get { optedIn }
        set {
            optedIn = newValue
            // Honour opt-out immediately: drop anything already on disk.
            if !newValue { clear() }
        }
    }

    // MARK: - Local persistence

    private static let storeURL: URL = {
        AppSupport.directory().appendingPathComponent("telemetry.jsonl")
    }()

    private func appendLocal(_ record: Record) {
        guard let line = try? JSONEncoder().encode(record) else { return }
        let data = line + Data([0x0a])
        let url = Self.storeURL
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }
}
