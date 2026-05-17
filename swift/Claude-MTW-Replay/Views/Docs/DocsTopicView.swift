import SwiftUI

struct DocsTopicView: View {
    let topic: DocTopic
    let content: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(topic.category.uppercased())
                    .font(.caption2).foregroundStyle(.tertiary)
                MarkdownTextView(markdown: content)
                    .frame(maxWidth: 760, alignment: .leading)
                    .padding(.bottom, 80)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.top, 24)
        }
        .background(Color(NSColor.textBackgroundColor))
    }
}
