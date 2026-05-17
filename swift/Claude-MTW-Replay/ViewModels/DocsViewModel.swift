import Foundation
import Observation

@MainActor
@Observable
final class DocsViewModel {
    var selectedTopicId: String = "getting-started"
    var searchQuery: String = ""

    var currentTopic: DocTopic? {
        DocTopic.catalog.first(where: { $0.id == selectedTopicId })
    }

    var currentContent: String {
        currentTopic?.loadContent() ?? "# Welcome\n\nSelect a topic from the sidebar."
    }

    var searchResults: [(topic: DocTopic, snippet: String)] {
        DocsLoader.search(searchQuery)
    }

    func select(topicId: String) {
        selectedTopicId = topicId
    }
}
