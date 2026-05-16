import Foundation
import SwiftData

/// G8 — persisted "always allow / always deny" decision. Keyed by
/// (sessionPath, toolName, signature) so the user can answer a permission
/// prompt once and have the sidecar's `canUseTool` callback auto-resolve
/// future identical calls within the same session.
///
/// `signature` is a stable hash of the canonicalised tool input —
/// computed sidecar-side and forwarded verbatim — so the same Bash command
/// or file path matches across turns even if cosmetic fields (timestamps,
/// nonces) ride along inside the raw input dict.
@Model
final class PermissionDecisionEntity {
    var sessionPath: String
    var toolName: String
    var signature: String
    /// Raw value of `PermissionAction` ("allow" / "deny"). Stored as a
    /// String so SwiftData's predicate engine can compare it directly
    /// without bridging through the enum.
    var action: String
    var createdAt: Date

    init(
        sessionPath: String,
        toolName: String,
        signature: String,
        action: String,
        createdAt: Date = .now
    ) {
        self.sessionPath = sessionPath
        self.toolName = toolName
        self.signature = signature
        self.action = action
        self.createdAt = createdAt
    }
}
