import SwiftUI
struct TranscriptFilterBar: View {
    @Binding var showUser: Bool; @Binding var showAssistant: Bool; @Binding var showTools: Bool; @Binding var showThinking: Bool
    var body: some View {
        HStack(spacing: DesignTokens.space8) {
            Toggle("User", isOn: $showUser).toggleStyle(.button)
            Toggle("Assistant", isOn: $showAssistant).toggleStyle(.button)
            Toggle("Tools", isOn: $showTools).toggleStyle(.button)
            Toggle("Thinking", isOn: $showThinking).toggleStyle(.button)
            Spacer()
        }.padding(.horizontal, DesignTokens.space8).padding(.vertical, DesignTokens.space4)
    }
}
