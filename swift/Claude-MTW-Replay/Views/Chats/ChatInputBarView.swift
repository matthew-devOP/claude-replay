import SwiftUI
import AppKit

/// The bottom-of-chat input row.
///
/// v0.8.0-swift Phase 1 includes:
///   - Multi-line `TextEditor` with Cmd+Enter to send
///   - Send / Stop button (turns into Stop while streaming)
///   - Mode toggles (Plan / AcceptEdits / Default)
///   - Verbose toggle (Ctrl+R)
///   - Prefix chips: `@` opens NSOpenPanel and inlines file content,
///     `!` runs a shell command and inlines stdout, `#` types a literal
///     `#` so the SDK can pick it up as a memory directive
struct ChatInputBarView: View {
    @Environment(AppState.self) private var appState
    @Bindable var vm: ChatViewModel
    @FocusState private var inputFocused: Bool
    @State private var shellPrompt: String = ""
    @State private var showingShellSheet = false
    /// G9 — true while the user is dragging a file over the input
    /// container. Drives the accent-coloured drop overlay.
    @State private var isDropTargeted: Bool = false
    /// G10 — non-nil when the preview sheet is open for an attachment.
    @State private var previewing: ChatAttachment? = nil
    /// G7 — discovered slash commands (project + user level), refreshed
    /// on appear. Cheap enough that we don't bother watching for changes.
    @State private var slashCommands: [SlashCommand] = []
    /// G7 — non-nil when the draft starts with `/` and has no whitespace;
    /// drives the dropdown picker overlay above the input row.
    @State private var slashFilter: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            attachmentBar
            controlsRow
            inputRow
        }
        .padding(12)
        .onAppear {
            slashCommands = SlashCommandService.discover(
                projectPath: vm.projectPath,
                claudeAccountDir: appState.claudeAccountDir
            )
        }
        .onChange(of: vm.inputDraft) { _, newValue in
            // Activate the slash picker only while the draft is a single
            // token starting with `/` — once the user types a space (i.e.
            // begins writing arguments) we get out of the way.
            if newValue.hasPrefix("/") && !newValue.contains(" ") && !newValue.contains("\n") {
                slashFilter = String(newValue.dropFirst())
            } else {
                slashFilter = nil
            }
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.1))
                    )
                    .overlay(
                        Text("Drop file(s) to attach")
                            .foregroundStyle(.white)
                            .bold()
                    )
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            // Cap to 5 dropped items to match the VM's max-attachment policy.
            for provider in providers.prefix(5) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url {
                        Task { @MainActor in
                            vm.addAttachment(ChatAttachment.from(url: url))
                        }
                    }
                }
            }
            return true
        }
        .sheet(item: $previewing) { att in
            ChatAttachmentPreviewSheet(attachment: att)
        }
        .sheet(isPresented: $showingShellSheet) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Run shell command")
                    .font(.headline)
                Text("Stdout + stderr will be appended to your message (max 16 KB).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. ls -la", text: $shellPrompt)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { confirmShellRun() }
                HStack {
                    Spacer()
                    Button("Cancel") { showingShellSheet = false }
                        .keyboardShortcut(.cancelAction)
                    Button("Run") { confirmShellRun() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(shellPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(20)
            .frame(width: 480)
        }
    }

    private func confirmShellRun() {
        let cmd = shellPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }
        showingShellSheet = false
        runShellAndInline(cmd)
    }

    // MARK: - Attachment bar (G9/G10)

    /// Horizontal strip of `ChatAttachmentChip`s shown above the
    /// controls row when the user has staged any files. Hidden when
    /// the pending list is empty so the input bar keeps its compact
    /// resting height.
    @ViewBuilder
    private var attachmentBar: some View {
        if !vm.pendingAttachments.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(vm.pendingAttachments) { att in
                        ChatAttachmentChip(attachment: att) {
                            vm.removeAttachment(att)
                        } onTap: {
                            previewing = att
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(height: 36)
        }
    }

    // MARK: - Controls row (mode + prefix + verbose)

    private var controlsRow: some View {
        HStack(spacing: 8) {
            ModeToggleView(currentMode: vm.permissionMode) { newMode in
                Task { await vm.changeMode(newMode) }
            }
            Divider().frame(height: 18)
            prefixButton(label: "@", help: "Reference a file (inlines its contents)") {
                pickAndInlineFile()
            }
            prefixButton(label: "!", help: "Run a shell command and inline stdout") {
                shellPrompt = ""
                showingShellSheet = true
            }
            prefixButton(label: "#", help: "Add to memory (passes #-prefixed text to Claude)") {
                vm.inputDraft = (vm.inputDraft.isEmpty ? "" : vm.inputDraft + "\n") + "#"
                inputFocused = true
            }
            Spacer()
            Toggle(isOn: Binding(
                get: { vm.verbose },
                set: { newValue in Task { await vm.setVerbose(newValue) } }
            )) {
                Label("Verbose", systemImage: "text.alignleft")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
            }
            .toggleStyle(.button)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Stream partial messages (Ctrl+R)")
            .keyboardShortcut("r", modifiers: .control)
        }
    }

    private func prefixButton(label: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(.body, design: .monospaced).bold())
                .frame(width: 24, height: 22)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(help)
        .accessibilityLabel(accessibilityName(for: label))
        .accessibilityHint(help)
    }

    /// Map the single-character prefix glyphs to descriptive VoiceOver
    /// names so they aren't read as bare punctuation ("at sign", "bang",
    /// "hash"). Falls through to the literal label otherwise.
    private func accessibilityName(for label: String) -> String {
        switch label {
        case "@": return "Reference file"
        case "!": return "Run shell command"
        case "#": return "Add to memory"
        default:  return label
        }
    }

    // MARK: - Prefix actions

    /// Open NSOpenPanel, then prepend the chosen file as a fenced block to
    /// the current draft. Mirrors `@filename` in the TUI but client-side
    /// (we read the file ourselves rather than relying on the SDK to honour
    /// `@` syntax under stream-json).
    private func pickAndInlineFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: vm.projectPath)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let max = 64 * 1024 // 64KB safety guard
        var content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        if content.count > max {
            content = String(content.prefix(max)) + "\n…(truncated)"
        }
        let fenced = "@\(url.path):\n```\n\(content)\n```\n"
        vm.inputDraft = (vm.inputDraft.isEmpty ? fenced : vm.inputDraft + "\n" + fenced)
        inputFocused = true
    }

    /// Run a one-shot `/bin/sh -c <cmd>` and inline the combined stdout/stderr
    /// into the draft. Bound to a small modal sheet so the user can preview
    /// the command before it runs. Returns max 16KB of output.
    private func runShellAndInline(_ cmd: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", cmd]
        proc.currentDirectoryURL = URL(fileURLWithPath: vm.projectPath)
        let outPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = outPipe
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            let max = 16 * 1024
            var output = String(decoding: data, as: UTF8.self)
            if output.count > max { output = String(output.prefix(max)) + "\n…(truncated)" }
            let block = "!\(cmd)\n```\n\(output)```\n"
            vm.inputDraft = (vm.inputDraft.isEmpty ? block : vm.inputDraft + "\n" + block)
        } catch {
            vm.inputDraft += "\n[!shell failed: \(error.localizedDescription)]"
        }
        inputFocused = true
    }

    // MARK: - Input + Send/Stop

    private var inputRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if vm.inputDraft.isEmpty {
                    Text("Send a message… (Enter to send, Shift+Enter for newline)")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $vm.inputDraft)
                    .focused($inputFocused)
                    .scrollContentBackground(.hidden)
                    .padding(2)
                    .frame(minHeight: 36, maxHeight: 140)
                    .onSubmit { trySubmit() }
                    .onKeyPress(.return) {
                        // SwiftUI's TextEditor doesn't have a clean way to
                        // distinguish Enter from Shift+Enter without using
                        // an NSViewRepresentable. For Phase 1 we treat
                        // Cmd+Enter as send and let plain Enter newline,
                        // which is the more forgiving default for prose.
                        return .ignored
                    }
            }
            .background(appState.theme.bgSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(appState.theme.border, lineWidth: 1)
            )

            sendOrStopButton
        }
        .overlay(alignment: .topLeading) {
            if slashFilter != nil {
                SlashCommandPickerView(
                    commands: slashCommands,
                    filter: slashFilter ?? ""
                ) { cmd in
                    // Replace the draft with the expanded command body.
                    // `$ARGUMENTS` is currently empty — future work could
                    // pipe trailing tokens from `/cmd foo bar` through.
                    vm.inputDraft = cmd.expanded(args: "")
                    slashFilter = nil
                    inputFocused = true
                }
                .offset(y: -200) // float above the input row
            }
        }
    }

    @ViewBuilder
    private var sendOrStopButton: some View {
        if vm.status == .sending {
            Button {
                Task { await vm.cancel() }
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.red)
            .keyboardShortcut(.escape, modifiers: [])
            .help("Cancel current turn (Esc)")
            .accessibilityLabel("Stop current turn")
            .accessibilityHint("Cancels the in-flight assistant response")
        } else {
            Button {
                trySubmit()
            } label: {
                Label("Send", systemImage: "arrow.up.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(appState.theme.accent)
            .disabled(
                vm.inputDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && vm.pendingAttachments.isEmpty
            )
            .keyboardShortcut(.return, modifiers: .command)
            .help("Send (Cmd+Return)")
            .accessibilityLabel("Send message")
            .accessibilityHint("Submit the current draft (Command-Return)")
        }
    }

    private func trySubmit() {
        let hasText = !vm.inputDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAttachments = !vm.pendingAttachments.isEmpty
        guard hasText || hasAttachments else { return }
        Task { await vm.send() }
    }
}
