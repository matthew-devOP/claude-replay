# Export

> Turn any session — or a custom selection of turns — into a self-contained HTML, Markdown, or PDF file.

## Opening the export sheet

There are several ways to start an export:

- **Cmd+E** from anywhere in the app exports the current session with the current selection.
- The sessions table row action **MD** exports straight to Markdown using the row's session.
- The Editor toolbar **Export…** button uses `prepareTurnsForExport()` to drop excluded turns.
- The Chats header **Export** menu hands the live turns to the same pipeline.

## Formats

| Format | Output | Notes |
|---|---|---|
| **HTML** | Single self-contained file | Uses the same `player.html` template as the web app, with theme CSS inlined. |
| **Markdown** | `.md` file | Roles as headings, code fences for Bash, diff fences for Edit, `<details>` blocks for thinking. |
| **PDF** | Single PDF | The HTML is rendered offscreen in a `WKWebView`, then `webView.pdf(configuration: WKPDFConfiguration())` writes the document. |

All three roads end in `NSSavePanel`. The default filename combines the session id and the chosen format.

## Options

The Export sheet exposes:

- **Format** — HTML / Markdown / PDF.
- **Theme** — any of the eight built-in themes or any custom theme you have loaded (see [Settings → Custom Themes](settings.md#custom-themes)).
- **Speed** — `0.5x` to `20x`, discrete steps aligned with the Replay player (`speedSteps`).
- **Redact secrets** — toggle (default on); see [Settings → Security](settings.md#security).
- **Show thinking** — include the gray `thinking` blocks.
- **Show tool calls** — include tool disclosures.
- **User label** / **Assistant label** — override the role headings.
- **Title** — page `<title>` and PDF metadata.
- **Description** — `<meta name="description">` for HTML.
- **OG image URL** — the `og:image` for social previews. Defaults to the bundled image or the URL set in [Settings → Display](settings.md#display).

The **Export** button wires straight to `ExportViewModel.export(turns:options:)` and only dismisses the sheet on success; failures surface as an `.alert` with the underlying error.

## HTML compression

The HTML template embeds two JSON blobs — turns and bookmarks. By default each blob is compressed with raw zlib deflate (RFC 1951) and base64-encoded before being inlined. At runtime the page decompresses with `pako` (already bundled in the template). The 0x78 / 0x9C zlib header and 4-byte Adler-32 checksum are stripped so the result matches Node's `zlib.deflateSync()`.

Pass the `--no-compress` option (Settings → Display → "Embed JSON uncompressed") to disable compression. Useful when you want to crack open the file with `view-source:` and read the data directly.

## Self-contained vs linked

HTML and PDF exports are **self-contained**. No external CSS or JS is required — the file works offline and behind firewalls. The OG image is the one exception: it stays as a URL unless you bundle one locally.

## Import HTML Replay

The pipeline is bidirectional. **File → Import HTML Replay…** (Cmd+Shift+I) opens an `NSOpenPanel` filtered to `.html`. `HTMLExtractor` reverse-parses the two embedded blobs, decompresses them, and reconstructs the turns and bookmarks. The imported session opens in [Replay](replay.md) as an in-memory `ImportedSession` — not written to disk anywhere.

This is also a handy way to share replays with people who do not have the underlying JSONL: send the HTML, they double-click, and they get the same view you exported.

## Export from Chats

The header **Export** menu in [Chats](chats.md) re-uses `ExportViewModel`. Because chat turns are stored as the same `Turn` model the rest of the app uses, the export is 1:1 with what you saw in the conversation. Useful for archiving long sessions or sharing them with a teammate.

## Performance notes

- Markdown export is essentially instant.
- HTML export of a typical session (~500 turns) lands in under a second.
- PDF export depends on `WKWebView`; very long replays (~thousands of turns) may take several seconds and produce a multi-megabyte PDF. The progress indicator in `ExportProgressView` shows when the WebView finishes rendering.

Related: [Editor](editor.md) · [Settings](settings.md) · [Replay → Bookmarks](replay.md#bookmarks).
