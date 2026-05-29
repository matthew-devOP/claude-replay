import SwiftUI

struct DocsTopicView: View {
    let topic: DocTopic
    let content: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.space12) {
                Text(topic.category.uppercased())
                    .font(.caption2).foregroundStyle(.tertiary)
                MarkdownTextView(markdown: content)
                    .frame(maxWidth: 760, alignment: .leading)
                    .padding(.bottom, 80)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignTokens.space32)
            .padding(.top, DesignTokens.space24)
        }
        .background(Color(NSColor.textBackgroundColor))
    }
}
