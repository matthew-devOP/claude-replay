import Foundation

/// G8 — typed decision payload returned to the sidecar's `canUseTool`
/// callback. The raw string values match the SDK's `PermissionResult.behavior`
/// discriminator (`"allow"` / `"deny"`) so we can round-trip through JSON
/// without translation.
enum PermissionAction: String, Codable, Sendable {
    case allow
    case deny
}

/// G8 — UI hint for how long an allow/deny decision should stick. `once`
/// applies to this single tool call; `always` writes a row to
/// `PermissionDecisionEntity` so future calls with the same signature
/// auto-resolve. `never` is reserved for a future "remember as deny"
/// flow and currently behaves like `once`.
enum PermissionRemember: String, Codable, Sendable {
    case once
    case always
    case never
}

/// G8 — one pending permission prompt surfaced by the sidecar via a
/// `permission_request` event. We carry both a human-readable summary
/// (for the modal) and a stable `signature` (for the persistence cache)
/// so "always allow" works correctly even when the tool input contains
/// volatile fields like timestamps.
///
/// `id` is a fresh UUID per request so SwiftUI's `.sheet(item:)` /
/// `.alert(item:)` re-fire when a new prompt lands; `requestId` is
/// the opaque string we hand back to the sidecar so it knows which
/// pending `canUseTool` promise to resolve.
struct PermissionRequest: Identifiable, Equatable, Sendable {
    let id: UUID
    let toolName: String
    let toolInputSummary: String
    let signature: String
    let requestId: String

    init(
        id: UUID = UUID(),
        toolName: String,
        toolInputSummary: String,
        signature: String,
        requestId: String
    ) {
        self.id = id
        self.toolName = toolName
        self.toolInputSummary = toolInputSummary
        self.signature = signature
        self.requestId = requestId
    }
}
