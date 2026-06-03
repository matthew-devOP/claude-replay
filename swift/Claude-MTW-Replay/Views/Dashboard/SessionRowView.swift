import SwiftUI

/// One row in the Sessions table — id chip, preview text, date, duration,
/// turns, size, action buttons. Hovering the row reveals the first few
/// user messages (mirrors the web's hover popover).
struct SessionRowView: View {
    @Environment(AppState.self) private var appState
    let session: SessionEntry
    let isCompareSelected: Bool
    let compareMode: Bool
    let onTapCompare: () -> Void
    let onAction: (SessionRowAction, SessionEntry) -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 0) {
            sessionIdCell
            if appState.isAllAccounts { accountCell }
            previewCell
            createdCell
            dateCell
            durationCell
            turnsCell
            sizeCell
            actionsCell
            compareCell
        }
        .padding(.horizontal, DesignTokens.space16)
        .padding(.vertical, DesignTokens.space10)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .popover(isPresented: hoverPopoverBinding, arrowEdge: .top) { hoverPopoverContent }
    }

    // MARK: - Cells

    private var sessionIdCell: some View {
        HStack(spacing: DesignTokens.space4) {
            if appState.favoritesVM.isFavorite(session.path) {
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(appState.theme.accent)
            } else {
                Image(systemName: "star")
                    .font(.system(size: 9))
                    .foregroundStyle(appState.theme.textDim.opacity(0.5))
            }
            Text(String(session.sessionId.prefix(8)))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(appState.theme.accent)
        }
        .frame(width: 130, alignment: .leading)
        .padding(.trailing, DesignTokens.space8)
        .onTapGesture {
            appState.favoritesVM.toggle(
                path: session.path,
                sessionId: session.sessionId,
                preview: session.preview ?? "",
                projectDir: appState.selectedProject?.path ?? ""
            )
        }
        .help("Toggle favorite")
    }

    private var previewCell: some View {
        Text(session.preview ?? "")
            .font(.caption)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, DesignTokens.space8)
            .redacted(reason: session.preview == nil ? .placeholder : [])
    }

    private var accountCell: some View {
        HStack(spacing: 0) {
            AccountBadge(label: session.accountLabel)
            Spacer(minLength: 0)
        }
        .frame(width: 90, alignment: .leading)
        .padding(.trailing, DesignTokens.space8)
    }

    private var createdCell: some View {
        Text((session.createdDate ?? session.date)?.shortRelativeString() ?? "—")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(width: 110, alignment: .leading)
            .padding(.trailing, DesignTokens.space8)
    }

    private var dateCell: some View {
        Text(session.date?.shortRelativeString() ?? "—")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(width: 110, alignment: .leading)
            .padding(.trailing, DesignTokens.space8)
    }

    private var durationCell: some View {
        Text(session.durationSeconds.map { $0.formattedDuration() } ?? "—")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(width: 110, alignment: .leading)
            .padding(.trailing, DesignTokens.space8)
            .redacted(reason: session.turnCount == nil ? .placeholder : [])
    }

    private var turnsCell: some View {
        Text(session.turnCount.map { "\($0)" } ?? "—")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(width: 80, alignment: .trailing)
            .padding(.trailing, DesignTokens.space8)
            .redacted(reason: session.turnCount == nil ? .placeholder : [])
    }

    private var sizeCell: some View {
        Text(session.size.formattedFileSize())
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(width: 90, alignment: .trailing)
            .padding(.trailing, DesignTokens.space8)
    }

    private var actionsCell: some View {
        HStack(spacing: DesignTokens.space6) {
            actionButton("Replay", icon: "play.fill", prominent: true) { onAction(.replay, session) }
            actionButton("Transcript", icon: "doc.text") { onAction(.transcript, session) }
            actionButton("Edit", icon: "pencil") { onAction(.edit, session) }
            actionButton("MD", icon: "arrow.down.doc") { onAction(.markdown, session) }
        }
        .frame(width: 280, alignment: .leading)
    }

    private var compareCell: some View {
        Group {
            if compareMode {
                Button {
                    onTapCompare()
                } label: {
                    Image(systemName: isCompareSelected ? "checkmark.square.fill" : "square")
                        .foregroundStyle(isCompareSelected ? appState.theme.accent : .secondary)
                }
                .buttonStyle(.plain)
                .help("Toggle compare selection")
            } else {
                Color.clear
            }
        }
        .frame(width: 70)
    }

    // MARK: - Helpers

    private func actionButton(_ label: String, icon: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .labelStyle(.titleOnly)
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(prominent ? appState.theme.accent : .secondary)
    }

    private var rowBackground: some View {
        let base: Color = isCompareSelected ? appState.theme.accent.opacity(0.08)
            : (isHovering ? appState.theme.bgHover.opacity(0.4) : .clear)
        return Rectangle().fill(base)
    }

    /// Show the hover popover only when (a) the user is hovering the row
    /// AND (b) we have user previews to show. Avoids flicker before
    /// metadata enrichment lands.
    private var hoverPopoverBinding: Binding<Bool> {
        Binding(
            get: {
                isHovering && !(session.userPreviews ?? []).isEmpty
            },
            set: { _ in /* read-only — driven by hover state */ }
        )
    }

    @ViewBuilder
    private var hoverPopoverContent: some View {
        VStack(alignment: .leading, spacing: DesignTokens.space10) {
            ForEach(Array((session.userPreviews ?? []).enumerated()), id: \.offset) { idx, text in
                VStack(alignment: .leading, spacing: DesignTokens.space2) {
                    Text("Turn \(idx + 1)")
                        .font(.caption2.smallCaps())
                        .foregroundStyle(appState.theme.accent)
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(4)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(DesignTokens.space14)
        .frame(maxWidth: 380, alignment: .leading)
    }
}

/// Per-row action types fired by `SessionRowView`'s buttons.
enum SessionRowAction {
    case replay
    case transcript
    case edit
    case markdown
}
