import Foundation
import SwiftUI

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
    }

    func record(_ event: Event) {
        guard optedIn else { return }
        if anonymousId.isEmpty {
            anonymousId = UUID().uuidString
        }
        // No backend yet — just log to stderr until a real endpoint is wired.
        print("[Telemetry] \(event.name) (id: \(anonymousId.prefix(8)))")
    }

    /// Public for UI to read & set
    var isOptedIn: Bool {
        get { optedIn }
        set { optedIn = newValue }
    }
}
