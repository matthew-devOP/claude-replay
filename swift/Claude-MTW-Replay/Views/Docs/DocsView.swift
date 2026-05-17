import SwiftUI

struct DocsView: View {
    @State private var vm = DocsViewModel()

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                searchBar
                if vm.searchQuery.isEmpty {
                    DocsSidebarView(vm: vm)
                } else {
                    searchResults
                }
            }
        } detail: {
            if let topic = vm.currentTopic {
                DocsTopicView(topic: topic, content: vm.currentContent)
            } else {
                ContentUnavailableView("Select a topic", systemImage: "book.closed")
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onReceive(NotificationCenter.default.publisher(for: .docsDidRequestTopic)) { notif in
            if let topicId = notif.object as? String {
                vm.select(topicId: topicId)
                vm.searchQuery = ""
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search docs…", text: $vm.searchQuery)
                .textFieldStyle(.plain)
            if !vm.searchQuery.isEmpty {
                Button { vm.searchQuery = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(8)
    }

    private var searchResults: some View {
        List {
            ForEach(Array(vm.searchResults.enumerated()), id: \.offset) { _, hit in
                Button {
                    vm.select(topicId: hit.topic.id)
                    vm.searchQuery = ""
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(hit.topic.title).font(.body)
                        Text(hit.snippet)
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }
        }
    }
}
