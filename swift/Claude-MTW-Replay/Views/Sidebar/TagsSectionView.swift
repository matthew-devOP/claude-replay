import SwiftUI

struct TagsSectionView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = TagsViewModel()

    var body: some View {
        Section("Tags") {
            if vm.tagsGrouped.isEmpty {
                Text("No tags yet")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(sortedTags, id: \.self) { tag in
                    DisclosureGroup {
                        ForEach(vm.tagsGrouped[tag] ?? [], id: \.self) { path in
                            Button {
                                appState.selectSession(path)
                            } label: {
                                HStack {
                                    Image(systemName: "doc.text")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                    Text(displayName(for: path))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Remove tag from session", role: .destructive) {
                                    vm.removeTag(path: path, tag: tag)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "tag.fill")
                                .foregroundStyle(.blue)
                                .font(.caption)
                            Text(tag)
                            Spacer()
                            Text("\(vm.tagsGrouped[tag]?.count ?? 0)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .task {
            vm.load()
        }
    }

    private var sortedTags: [String] {
        vm.tagsGrouped.keys.sorted()
    }

    private func displayName(for path: String) -> String {
        let last = (path as NSString).lastPathComponent
        let trimmed = last.hasSuffix(".jsonl") ? String(last.dropLast(".jsonl".count)) : last
        if trimmed.count <= 24 { return trimmed }
        let prefix = trimmed.prefix(24)
        return String(prefix) + "…"
    }
}
