import Foundation

struct DocTopic: Identifiable, Hashable {
    let id: String  // file stem, e.g. "getting-started"
    let title: String
    let category: String  // e.g. "Basics", "Features", "Reference"
    let order: Int  // sort key within category
    let resourceName: String  // bundle resource for the .md file

    /// Loads markdown content lazily.
    @MainActor
    func loadContent() -> String {
        DocsLoader.load(topicId: id) ?? "# \(title)\n\nContent not found."
    }
}

extension DocTopic {
    /// Static catalog. Topics are sorted by (category order, then `order`).
    /// Categories follow this order: Basics, Features, Reference.
    static let catalog: [DocTopic] = [
        // Basics
        DocTopic(id: "getting-started",   title: "Getting Started",   category: "Basics", order: 0, resourceName: "getting-started"),
        DocTopic(id: "ui-overview",       title: "UI Overview",       category: "Basics", order: 1, resourceName: "ui-overview"),
        DocTopic(id: "accounts",          title: "Multi-Account",     category: "Basics", order: 2, resourceName: "accounts"),
        // Features
        DocTopic(id: "dashboard",         title: "Dashboard",         category: "Features", order: 0, resourceName: "dashboard"),
        DocTopic(id: "chats",             title: "Chats (Live Chat)", category: "Features", order: 1, resourceName: "chats"),
        DocTopic(id: "replay",            title: "Replay",            category: "Features", order: 2, resourceName: "replay"),
        DocTopic(id: "editor",            title: "Editor",            category: "Features", order: 3, resourceName: "editor"),
        DocTopic(id: "stats",             title: "Stats",             category: "Features", order: 4, resourceName: "stats"),
        DocTopic(id: "git",               title: "Git Integration",   category: "Features", order: 5, resourceName: "git"),
        DocTopic(id: "search",            title: "Search",            category: "Features", order: 6, resourceName: "search"),
        DocTopic(id: "export",            title: "Export",            category: "Features", order: 7, resourceName: "export"),
        // Reference
        DocTopic(id: "keyboard-shortcuts",title: "Keyboard Shortcuts",category: "Reference", order: 0, resourceName: "keyboard-shortcuts"),
        DocTopic(id: "settings",          title: "Settings",          category: "Reference", order: 1, resourceName: "settings"),
        DocTopic(id: "faq",               title: "FAQ",               category: "Reference", order: 2, resourceName: "faq"),
        DocTopic(id: "troubleshooting",   title: "Troubleshooting",   category: "Reference", order: 3, resourceName: "troubleshooting"),
    ]

    static let categoryOrder: [String] = ["Basics", "Features", "Reference"]

    static func grouped() -> [(String, [DocTopic])] {
        let dict = Dictionary(grouping: catalog) { $0.category }
        return categoryOrder.compactMap { cat in
            guard let topics = dict[cat] else { return nil }
            return (cat, topics.sorted { $0.order < $1.order })
        }
    }
}
