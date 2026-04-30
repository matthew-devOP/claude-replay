import SwiftUI

/// Live conversation view for one resumed Claude session.
///
/// Layout:
///   ┌────────────────────────────────────────────────────┐
///   │ header: project · session · mode chip · cost · ⓧ │
///   ├────────────────────────────────────────────────────┤
///   │ scrollable transcript (TranscriptTurnView per turn)│
///   │  …auto-scrolls to bottom when new turns arrive…   │
///   ├────────────────────────────────────────────────────┤
///   │ ChatInputBarView                                  │
///   └────────────────────────────────────────────────────┘
///
/// Wires up `ChatViewModel` on appear and tears it down on dismiss.
/// All UI is theme-aware via `AppState.theme`.
struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var vm: ChatViewModel
    @State private var lastTurnId: UUID?

    init(sessionPath: String, projectPath: String) {
        _vm = State(wrappedValue: ChatViewModel(sessionPath: sessionPath, projectPath: projectPath))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            transcript
            Divider()
            ChatInputBarView(vm: vm)
        }
        .background(appState.theme.bg)
        .task { await vm.start() }
        .onDisappear {
            Task { await vm.cancel() }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "bubble.left.and.exclamationmark.bubble.right")
                .foregroundStyle(appState.theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(URL(fileURLWithPath: vm.sessionPath).lastPathComponent
                    .replacingOccurrences(of: ".jsonl", with: ""))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
                Text(vm.projectPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .truncationMode(.middle)
                    .lineLimit(1)
            }
            Spacer()
            statusChip
            if vm.cumulativeCostUsd > 0 {
                Text(String(format: "$%.4f", vm.cumulativeCostUsd))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .help("Cumulative cost this chat session")
            }
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(12)
    }

    @ViewBuilder
    private var statusChip: some View {
        switch vm.status {
        case .idle:
            Label("Idle", systemImage: "pause.circle")
                .labelStyle(.titleAndIcon)
                .font(.caption)
                .foregroundStyle(.secondary)
        case .starting:
            HStack(spacing: 4) {
                ProgressView().scaleEffect(0.6)
                Text("Connecting…").font(.caption)
            }
            .foregroundStyle(.secondary)
        case .ready:
            Label("Ready", systemImage: "circle.fill")
                .labelStyle(.iconOnly)
                .foregroundStyle(.green)
                .font(.caption)
        case .sending:
            HStack(spacing: 4) {
                ProgressView().scaleEffect(0.6)
                Text("Streaming…").font(.caption)
            }
            .foregroundStyle(appState.theme.accent)
        case .error(let m):
            Label(m, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(vm.turns) { turn in
                        TranscriptTurnView(turn: turn)
                            .id(turn.id)
                            .padding(.horizontal, 20)
                    }
                    if vm.status == .sending {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.7)
                            Text("Claude is composing…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                        .id("composing-indicator")
                    }
                }
                .padding(.vertical, 16)
            }
            .onChange(of: vm.turns.last?.id) { _, newId in
                guard let id = newId else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
            .onChange(of: vm.status) { _, _ in
                if vm.status == .sending {
                    withAnimation { proxy.scrollTo("composing-indicator", anchor: .bottom) }
                }
            }
        }
    }
}
