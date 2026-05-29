import SwiftUI

/// G4 — Dropdown picker for the SDK model id used by the current chat.
///
/// Renders as a toolbar Menu showing the currently-selected label (or
/// "Model" when SDK default). Changing the selection mutates the binding
/// and fires `onChange`, which the host view uses to respawn the sidecar
/// with the new `--model` flag.
///
/// Pricing tooltips are best-effort — they only need to be ballpark-
/// correct because the live cost chip in the header surfaces the true
/// per-turn USD reported by the SDK.
struct ChatModelOption: Identifiable, Hashable {
    let id: String        // sdk model id
    let label: String     // user-friendly
    let pricingPer1M: String  // tooltip
}

struct ChatModelPickerView: View {
    @Binding var selected: String?
    let onChange: () -> Void  // trigger respawn

    static let options: [ChatModelOption] = [
        ChatModelOption(id: "claude-opus-4-7",   label: "Opus 4.7",   pricingPer1M: "$15 / $75 per 1M tokens"),
        ChatModelOption(id: "claude-sonnet-4-6", label: "Sonnet 4.6", pricingPer1M: "$3 / $15 per 1M tokens"),
        ChatModelOption(id: "claude-haiku-4-5",  label: "Haiku 4.5",  pricingPer1M: "$1 / $5 per 1M tokens"),
    ]

    /// Returns `id` only if it's one of the offered models; otherwise nil
    /// (SDK default). Guards a stale/persisted/hand-edited model id from
    /// reaching the SDK, where an unknown id would error the whole turn.
    static func validatedModelID(_ id: String?) -> String? {
        guard let id, options.contains(where: { $0.id == id }) else { return nil }
        return id
    }

    var body: some View {
        Menu {
            Button("Default (SDK)") {
                selected = nil
                onChange()
            }
            Divider()
            ForEach(Self.options) { opt in
                Button {
                    selected = opt.id
                    onChange()
                } label: {
                    HStack {
                        Text(opt.label)
                        Spacer()
                        if selected == opt.id { Image(systemName: "checkmark") }
                    }
                }
                .help(opt.pricingPer1M)
            }
        } label: {
            let label = Self.options.first(where: { $0.id == selected })?.label ?? "Model"
            Label(label, systemImage: "cpu")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Pick the SDK model for this chat (respawns the agent)")
    }
}
