import SwiftUI

/// Toolbar menu that lists all Claude accounts detected under $HOME
/// (~/.claude, ~/.claude-work, ...) and switches the active one.
/// Swapping the account clears selections and triggers a reload via
/// the `.task(id: claudeAccountDir)` binding on the sidebar.
struct AccountSwitcherMenu: View {
    @Environment(AppState.self) private var appState
    @State private var accounts: [ClaudeAccount] = []

    var body: some View {
        Menu {
            // Virtual "ALL accounts" entry — aggregate across every account.
            // Only meaningful with 2+ real accounts.
            if accounts.count > 1 {
                Button {
                    guard !appState.isAllAccounts else { return }
                    appState.setClaudeAccount(AccountStore.allDirName)
                } label: {
                    if appState.isAllAccounts {
                        Label("ALL accounts", systemImage: "checkmark")
                    } else {
                        Label("ALL accounts", systemImage: "person.3")
                    }
                }
                Divider()
            }
            ForEach(accounts) { account in
                Button {
                    guard account.dirName != appState.claudeAccountDir else { return }
                    appState.setClaudeAccount(account.dirName)
                } label: {
                    if account.dirName == appState.claudeAccountDir {
                        Label(account.label, systemImage: "checkmark")
                    } else {
                        Text(account.label)
                    }
                }
            }
        } label: {
            Label(currentLabel, systemImage: appState.isAllAccounts ? "person.3" : "person.crop.circle")
        }
        .help("Switch Claude account")
        .onAppear { accounts = AccountStore.availableAccounts() }
    }

    private var currentLabel: String {
        if appState.isAllAccounts { return "ALL" }
        return accounts.first(where: { $0.dirName == appState.claudeAccountDir })?.label
            ?? (appState.claudeAccountDir == ".claude" ? "main" : appState.claudeAccountDir)
    }
}

/// A small pill showing which account a session/project came from, used in the
/// ALL-accounts view. Colour is derived deterministically from the label so the
/// same account always reads the same hue (mirrors the web `.account-badge`).
struct AccountBadge: View {
    let label: String
    var small: Bool = false

    var body: some View {
        Text(label)
            .font(small ? .system(size: 9, weight: .semibold)
                        : .system(size: 10, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, small ? 6 : 7)
            .padding(.vertical, small ? 1 : 2)
            .foregroundStyle(Color(hue: hue, saturation: 0.55, brightness: 0.85))
            .background(Capsule().fill(Color(hue: hue, saturation: 0.45, brightness: 0.30)))
            .overlay(Capsule().stroke(Color(hue: hue, saturation: 0.45, brightness: 0.45), lineWidth: 1))
            .help("Account: \(label)")
    }

    /// Deterministic 0…1 hue from the label characters (matches the web's
    /// `h = (h*31 + c) % 360` hashing, normalised to a SwiftUI hue).
    private var hue: Double {
        var h = 0
        for scalar in label.unicodeScalars {
            h = (h &* 31 &+ Int(scalar.value)) % 360
        }
        return Double(h) / 360.0
    }
}
