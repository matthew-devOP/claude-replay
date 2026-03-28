import SwiftUI
struct FilesAccessedView: View {
    let read: [String]; let edited: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !edited.isEmpty {
                Text("Files Edited (\(edited.count))").font(.headline)
                ForEach(edited, id: \.self) { Text($0).font(.system(.caption, design: .monospaced)) }
            }
            if !read.isEmpty {
                Text("Files Read (\(read.count))").font(.headline)
                ForEach(read, id: \.self) { Text($0).font(.system(.caption, design: .monospaced)) }
            }
        }
    }
}
