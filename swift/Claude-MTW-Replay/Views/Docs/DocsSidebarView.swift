import SwiftUI

struct DocsSidebarView: View {
    @Bindable var vm: DocsViewModel

    var body: some View {
        List(selection: Binding(get: { vm.selectedTopicId }, set: { if let v = $0 { vm.selectedTopicId = v } })) {
            ForEach(DocTopic.grouped(), id: \.0) { category, topics in
                Section(category) {
                    ForEach(topics) { topic in
                        Label(topic.title, systemImage: "doc.text")
                            .tag(topic.id)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220, idealWidth: 240)
    }
}
