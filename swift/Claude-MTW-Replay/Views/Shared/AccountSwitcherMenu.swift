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
            Label(currentLabel, systemImage: "person.crop.circle")
        }
        .help("Switch Claude account")
        .onAppear { accounts = AccountStore.availableAccounts() }
    }

    private var currentLabel: String {
        accounts.first(where: { $0.dirName == appState.claudeAccountDir })?.label
            ?? (appState.claudeAccountDir == ".claude" ? "main" : appState.claudeAccountDir)
    }
}
