import Foundation
import AppKit
import UniformTypeIdentifiers
@preconcurrency import WebKit

@Observable
final class ExportViewModel {
    var format: ExportFormat = .html
    var theme: String = "tokyo-night"
    var speed: Double = 1.0
    var isExporting = false
    var errorMessage: String?

    enum ExportFormat: String, CaseIterable { case html, markdown, pdf }

    func export(turns: [Turn], options: ExportOptions) async {
        isExporting = true
        defer { isExporting = false }

        switch format {
        case .html:
            await exportHTML(turns: turns, options: options)
        case .markdown:
            await exportMarkdown(turns: turns, title: options.title)
        case .pdf:
            await exportPDF(turns: turns, options: options)
        }
    }

    // MARK: - HTML

    private func exportHTML(turns: [Turn], options: ExportOptions) async {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = "replay.html"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let renderOpts = renderOptions(from: options)
            let html = HTMLRenderer.render(turns: turns, options: renderOpts)
            try html.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Markdown

    private func exportMarkdown(turns: [Turn], title: String?) async {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = "replay.md"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let md = MarkdownExporter.turnsToMarkdown(turns, title: title)
            try md.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - PDF (render HTML then print to PDF)

    private func exportPDF(turns: [Turn], options: ExportOptions) async {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "replay.pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let renderOpts = renderOptions(from: options)
            let html = HTMLRenderer.render(turns: turns, options: renderOpts)
            let pdfData = try await renderHTMLToPDF(html)
            try pdfData.write(to: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func renderOptions(from opts: ExportOptions) -> RenderOptions {
        let theme = Theme.named(opts.theme)
        let themeCss = ThemeService.themeToCss(
            (try? ThemeService.getTheme(opts.theme.rawValue)) ?? [:]
        )
        return RenderOptions(
            speed: opts.speed,
            showThinking: opts.showThinking,
            showToolCalls: opts.showToolCalls,
            themeCss: themeCss,
            themeBg: theme.bg.toHex() ?? "#1a1b26",
            userLabel: opts.userLabel,
            assistantLabel: opts.assistantLabel,
            title: opts.title,
            description: opts.description,
            ogImage: opts.ogImage ?? "https://es617.github.io/claude-replay/og.png",
            compress: opts.compress,
            redactSecrets: opts.redactSecrets,
            bookmarks: opts.bookmarks
        )
    }

    @MainActor
    private func renderHTMLToPDF(_ html: String) async throws -> Data {
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        webView.loadHTMLString(html, baseURL: nil)

        // Wait for the page to finish loading
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let delegate = PDFNavigationDelegate { error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume() }
            }
            // Prevent delegate from being deallocated by retaining via objc_setAssociatedObject
            objc_setAssociatedObject(webView, "navDelegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            webView.navigationDelegate = delegate
        }

        // Create PDF data using WKWebView's built-in method
        let pdfConfig = WKPDFConfiguration()
        pdfConfig.rect = .zero // Use content size
        return try await webView.pdf(configuration: pdfConfig)
    }
}

// MARK: - Helper for WKWebView load completion

private final class PDFNavigationDelegate: NSObject, WKNavigationDelegate, @unchecked Sendable {
    private let completion: (Error?) -> Void

    init(completion: @escaping (Error?) -> Void) {
        self.completion = completion
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        completion(nil)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        completion(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        completion(error)
    }
}
