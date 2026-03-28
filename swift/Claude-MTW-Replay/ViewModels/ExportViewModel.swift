import Foundation
import AppKit

@Observable
final class ExportViewModel {
    var format: ExportFormat = .html
    var isExporting = false
    var errorMessage: String?

    enum ExportFormat: String, CaseIterable { case html, markdown, pdf }

    func export(turns: [Turn], options: ExportOptions) async {
        isExporting = true
        defer { isExporting = false }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = "replay.html"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let html = try HTMLRenderer.render(turns: turns, options: options)
            try html.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
