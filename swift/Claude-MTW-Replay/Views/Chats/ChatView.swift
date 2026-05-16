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
    @State private var exportVM = ExportViewModel()

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
            Text(String(format: "$%.4f", vm.cumulativeCostUsd))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .help("Cumulative cost this chat session")
            Text(String(format: "Δ $%.4f", vm.lastTurnCostUsd))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .help("Cost of the last assistant turn")
            tokenChips
            Menu {
                Button("Export as HTML…") { exportChat(format: .html) }
                Button("Export as Markdown…") { exportChat(format: .markdown) }
                Button("Export as PDF…") { exportChat(format: .pdf) }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(vm.turns.isEmpty)
            .help("Export this chat to a file")
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(12)
    }

    /// G12 — cumulative token counters next to the cost chips. We only
    /// surface input/output by default; cache reads appear once non-zero
    /// so casual users aren't distracted in cold sessions.
    @ViewBuilder
    private var tokenChips: some View {
        HStack(spacing: 4) {
            Text("↑\(vm.cumulativeInputTokens)")
                .help("Cumulative input tokens (this chat)")
            Text("↓\(vm.cumulativeOutputTokens)")
                .help("Cumulative output tokens (this chat)")
            if vm.cumulativeCacheReadTokens > 0 {
                Text("⚡\(vm.cumulativeCacheReadTokens)")
                    .help("Cumulative cache-read tokens")
            }
        }
        .font(.caption.monospaced())
        .foregroundStyle(.secondary)
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
                            Text("Claude is composing")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            // G11 — blinking caret to signal "still streaming"
                            // even between visible delta arrivals.
                            CaretBlinkView()
                                .foregroundStyle(appState.theme.accent)
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
                // G11 — gentle spring instead of linear easeOut for smoother
                // autoscroll when a new turn lands mid-conversation.
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
            .onChange(of: vm.status) { _, _ in
                if vm.status == .sending {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        proxy.scrollTo("composing-indicator", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Export

    /// Spawn an export of the current chat in the chosen format. Reuses
    /// `ExportViewModel.export(turns:options:)` so we get the same NSSavePanel,
    /// theming, redaction, and PDF rendering as the Replay view.
    private func exportChat(format: ExportViewModel.ExportFormat) {
        exportVM.format = format
        exportVM.theme = "tokyo-night"
        var options = ExportOptions.default
        let sessionName = URL(fileURLWithPath: vm.sessionPath).lastPathComponent
            .replacingOccurrences(of: ".jsonl", with: "")
        options.title = sessionName
        Task {
            await exportVM.export(turns: vm.turns, options: options)
        }
    }
}

/// G11 — small "▌" caret whose opacity pulses to signal active streaming.
/// We animate opacity rather than swapping the glyph so the surrounding
/// text layout never shifts mid-flight.
private struct CaretBlinkView: View {
    @State private var visible = true
    var body: some View {
        Text("▌")
            .font(.system(.body, design: .monospaced))
            .opacity(visible ? 1 : 0.15)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    visible.toggle()
                }
            }
            .accessibilityHidden(true)
    }
}
