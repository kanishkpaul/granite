# Native macOS Technical Foundation for a Local-First Markdown Knowledge Base (Nov 2026)

> Scope: everything except the AI/ML layer and Zotero. Researched 2026-11-08.
>
> **Important version context the brief did not anticipate:** WWDC26 (June 8, 2026) announced **macOS 27 "Golden Gate"**, and it is the current release. It is **Apple Silicon only** (M1 or newer), and macOS 26 Tahoe is the last release for Intel Macs — [TechRadar](https://techradar.com/computing/mac-os/macos-27-golden-gate-announced-at-wwdc-2026-heres-everything-you-need-to-know); [MacTrast](https://www.mactrast.com/?p=172500). Sources disagree on the exact GA date. One reports a September 15 launch — [aitoolly](https://aitoolly.com/ai-news/article/2026-09-15-apple-releases-macos-27-golden-gate-featuring-siri-ai-and-exclusive-apple-silicon-support) — but that is a low-quality aggregator. For a personal app on one Apple Silicon Mac, targeting **macOS 26 as the minimum, with macOS 27 APIs behind `#available`**, is reasonable. "macOS 26+" below marks APIs introduced at WWDC25, and "macOS 27+" marks WWDC26 APIs.

## Text editing: best approach for a fast Markdown editor (TextKit 2, SwiftUI TextEditor, web editor, parsers)

### Takeaway
SwiftUI's `TextEditor` with `AttributedString` (macOS 26+) can't host a serious Markdown live-preview editor: it lacks the TextKit hooks, and lists and tables aren't exposed. The realistic choices are (a) AppKit `NSTextView`/TextKit (or STTextView) wrapped in `NSViewRepresentable`, or (b) CodeMirror 6 in a `WKWebView`, which is what MarkEdit does. A solo developer working with AI agents who wants Obsidian-like live preview at large file sizes gets the best risk-adjusted result from **CodeMirror 6 in WKWebView**. Native TextKit 2 is still possible but has known viewport and scrolling problems.

### Cited Findings
- **SwiftUI rich text (macOS 26+):** WWDC25 session 280 shows how to build rich text editing with `TextEditor` bound to `AttributedString`. Supported attributes include bold, italic, underline, strikethrough, fonts, foreground and background colors, kerning, tracking, baseline offset, and paragraph styles (line height, alignment, writing direction) — [Apple WWDC25 280](https://developer.apple.com/wwdc25/280/); [Apple (zh-CN transcript)](https://developer.apple.com/cn/videos/play/wwdc2025/280/?time=202).
- Selection is exposed through an `AttributedTextSelection` binding (`TextEditor(text:selection:)`), gated to iOS/macOS 26 — [skills.cat summary](https://skills.cat/skills/rshankras/claude-code-apple-skills/attributed-string); [createwithswift](https://www.createwithswift.com/using-rich-text-in-the-texteditor-with-swiftui/). Third-party summaries say `TextEditor` doesn't expose lists or tables and that anything beyond basic rich text still needs the full TextKit stack — [claudskills TextEditor skill](https://claudskills.com/skills/txt-swiftui-texteditor/SKILL.md); [sharedcontext apple-text-texteditor-26](https://sharedcontext.ai/skills/external/sitapix/apple-text-texteditor-26). These are secondary sources.
- **No new WWDC26 text APIs found.** Searches for WWDC26 TextEditor, TextKit, or AttributedString changes returned only WWDC25 material, and the WWDC26 macOS guide lists no text-editing announcements — [Apple WWDC26 macOS guide](https://developer.apple.com/wwdc26/guides/macos/).
- **TextKit 2 state (Aug 2025):** Marcin Krzyżanowski, author of STTextView, the main open-source TextKit 2 `NSTextView` replacement, wrote after four years of work that TextKit 2 "might not be the best tool for text layout," especially for editing UI. His specific complaints:
  - Viewport layout estimates document height, and `usageBoundsForTextContainer` swings as you scroll, so the scroller jumps.
  - Jumping to the end of a document needs fragile workarounds.
  - In practice only `NSTextContentStorage` with `NSTextParagraph` works.
  - Bugs regress between releases, and the "extra line fragment" issue persists.
  - TextEdit shows the same glitches.
  — [krzyzanowskim blog, "TextKit 2 – the promised land"](https://blog.krzyzanowskim.com/2025/08/14/textkit-2-the-promised-land/)
- STTextView tracks filed TextKit 2 bugs, for example FB14700414 (NSTextList broken since macOS 14) and FB15131180 (incorrect extra line frame) — [STTextView GitHub](https://www.github.com/krzyzanowskim/STTextView).
- **Opting out of TextKit 2:** `NSTextView` can be forced back to TextKit 1 (for example by touching `layoutManager`). Indie developers have done this deliberately — [Indiestack, "Opting Out of TextKit 2 in NSTextView"](https://indiestack.com/2022/11/opting-out-of-textkit2-in-nstextview/).
- **MarkEdit (open source, MIT):** A Swift and AppKit document-based app whose editor core is CodeMirror 6 running in the system WebView, not Electron. Its stated reasons: TextKit is "not better than contentEditable," and multi-caret editing and folding are hard to build on it. It claims 10 MB files open quickly on an eight-year-old MacBook Pro, with no benchmarks. It keeps native Look Up, spell check, Writing Tools, Services, and Shortcuts. The download is about 4 MB. Acknowledged downsides: non-native feel, and no full HTML preview or export — [MarkEdit wiki "Why MarkEdit"](https://github.com/MarkEdit-app/MarkEdit/wiki/Why-MarkEdit); [MarkEdit README](https://github.com/MarkEdit-app/MarkEdit). A June 2026 review of it — [brycewray.com](https://brycewray.com/posts/2026/06/markedit-textedit-markdown/).
- **Other Swift editors to study:**
  - CotEditor is a native AppKit/`NSTextView` plain-text and code editor — [CotEditor GitHub](https://github.com/coteditor/CotEditor).
  - FSNotes is a Swift, MIT-licensed Markdown notes app with `[[wikilinks]]`, Mermaid, MathJax, and optional git — [FSNotes GitHub](https://GitHub.com/glushchenko/fsnotes).

### Inferences
- **Recommended editor stack:**
  - Use CodeMirror 6 in a `WKWebView` (MarkEdit's pattern) for the main Markdown editor. It provides decorations for live-preview styling, hiding Markdown syntax off the cursor line much like Obsidian's own CM6-based Live Preview, plus autocompletion (`@codemirror/autocomplete` for `[[wikilink` and `#tag` completion), folding, multi-cursor, and good large-file performance. Connect Swift and JS with `WKScriptMessageHandler` and `callAsyncJavaScript`.
  - AI agents are very fluent in CodeMirror and TypeScript, which matters for a solo developer.
  - **Cost:** a JS build step, a bridge layer, and a slightly non-native feel for things like the context menu and IME edge cases.
- **Native alternative:** Use an `NSTextView` subclass, or STTextView, wrapped in `NSViewRepresentable`, with incremental re-styling of edited paragraphs from a Markdown parser. This feels most native, but you inherit the TextKit 2 viewport and scrolling bugs above, or the older TextKit 1 APIs. Reserve SwiftUI `TextEditor` + `AttributedString` for small fields such as frontmatter property editors and quick-capture panels.
- **Parsing in Swift (indexing, link and block extraction):**
  - Apple's `swift-markdown` wraps cmark-gfm, gives a typed AST with visitors and source ranges, and suits extracting links, headings, and blocks for the index.
  - Wikilinks (`[[...]]`), block IDs (`^id`), embeds, and callouts aren't CommonMark, so expect a small custom pre-pass or regex layer on top of it.
  - Down (cmark wrapper) is older and less active. tree-sitter (via SwiftTreeSitter) suits code-block highlighting and "code knowledge" ingestion more than Markdown structure.
  - These parser claims come from background knowledge and were not re-verified this session (see Gaps).

### Gaps
- No independent benchmark compares a CodeMirror 6 WKWebView editor with TextKit 1 or 2 editors. MarkEdit's numbers are self-reported.
- I couldn't confirm any WWDC26 (macOS 27) changes to TextKit, `TextEditor`, or AttributedString Markdown parsing. Session 269 ("What's new in SwiftUI") wasn't fetched in full.
- I didn't fetch or verify the current release status of swift-markdown, cmark-gfm, Down, or SwiftTreeSitter. Check their GitHub pages before committing.

## Storage and index: Markdown as truth, SQLite index (GRDB vs SwiftData vs Core Data, FTS5, sqlite-vec, schema, file watching, external edits, iCloud placeholders)

### Takeaway
Use **GRDB.swift 7.x** over a single SQLite file that is a disposable, rebuildable cache of the vault. Use FTS5 for full-text search, and a bundled sqlite-vec build if vectors live in the same database. SwiftData and Core Data fit "files are truth" poorly: they want to own the data, they add an abstraction cost, and SwiftData has reported scaling problems around 100k objects. File watching should combine FSEvents with periodic or startup reconciliation by mtime, size, and content hash, because external writers (Obsidian, git, agents, iCloud) will always race you.

### Cited Findings
- **GRDB 7.0.0 (Jan 26, 2025):**
  - It focused on Swift 6 concurrency. Async database access honors Task cancellation, and `ValueObservation` defaults to main-actor scheduling — [Swift Forums "GRDB 7 is out"](https://forums.swift.org/t/grdb-7-is-out/77465); [newreleases.io v7.0.0](https://newreleases.io/project/github/groue/GRDB.swift/release/v7.0.0); [mjtsai](https://mjtsai.com/blog/?p=46562).
  - The latest version confirmed was **7.10.0 (Feb 15, 2026)**, which requires Swift 6.1+ / Xcode 16.3+ — [CocoaPods GRDB](https://cocoapods.org/pods/NewGRDB.swift). Newer versions may exist; check GitHub.
  - FTS5 has been enabled by default in GRDB since 6.7.0 — [Swift Forums GRDB 6.7.0](https://forums.swift.org/t/new-release-grdb-6-7-0/63217). A 7.x changelog entry fixed cancellation of async tasks that use FTS5 — [mintlify changelog mirror](https://www.mintlify.com/groue/GRDB.swift/resources/changelog).
- **SwiftData vs GRDB:**
  - In a 2024 Emerge Tools comparison, SwiftData read performance "degraded sharply with over 100k objects" — [Reddit summary of Emerge comparison](https://cal1.lr.ggtyler.dev/r/iOSProgramming/comments/1dkmdeb/swiftdata_vs_realm_performance_comparison).
  - Fatbobman lists considerations to weigh before adopting SwiftData — [fatbobman](https://fatbobman.com/en/posts/key-considerations-before-using-swiftdata/).
  - In Point-Free's own benchmark, GRDB with manual decoding took about 18.8 s, generated raw SQLite about 7.2 s, and GRDB with Codable about 53 s. These are vendor numbers — [pointfreeco/sqlite-data](https://github.com/pointfreeco/sqlite-data).
  - Point-Free's **SQLiteData**, built on GRDB, is positioned as a SwiftData replacement with CloudKit sync and supersedes the deprecated SharingGRDB — [sqlite-data](https://github.com/pointfreeco/sqlite-data); [sharing-grdb](https://swiftpackageregistry.com/pointfreeco/sharing-grdb).
  - An HN commenter reported replacing SwiftData with GRDB and found GRDB "a pleasure to use" — [HN thread](https://hn.svelte.dev/item/45275582).
- **sqlite-vec from Swift:** There is no official Swift package, only community ones, so vet maintenance before depending on one:
  - **grdb-vector** is a custom GRDB SQLite build that bundles sqlite-vec 0.1.7, FTS5, and SQLite 3.47.2 against GRDB 7.10.0. Extensions must initialize before the connection opens. Its README points to two different repo URLs — [grdb-vector](https://github.com/xocialize-code/grdb-vector).
  - **SQLiteVecKit** bundles sqlite-vec with an API for vector, BM25, and hybrid search on iOS and macOS — [Swift Package Index SQLiteVecKit](https://swiftpackageindex.com/carlosypunto/SQLiteVecKit).
  - **SQLiteExtensionKit** builds with GRDB 7.8.0 on macOS 15+ — [SPI build log](https://swiftpackageindex.com/builds/22976D03-DACE-4FE2-AC01-5C4D28943BE2).
  - All of them rely on GRDB's documented "custom SQLite build" mechanism — [CocoaPods GRDB](https://cocoapods.org/pods/GRDB.swift).
  - The system SQLite on macOS doesn't allow loading arbitrary extensions in a way you should rely on, which is why bundling is the pattern (inference; see Gaps).
- **iCloud Drive placeholders:**
  - Evicted files have historically appeared as `.name.icloud` stubs.
  - Hard and symbolic links to evicted files break on eviction — [mjtsai](https://mjtsai.com/blog/wp-json/wp/v2/posts/21443).
  - `NSMetadataQuery` can observe the change to "not downloaded," and `FileManager.startDownloadingUbiquitousItem(at:)` re-downloads a file — [Stack Overflow archive](https://kiwix.lema.org/stackoverflow.com_en_all_2023-11/questions/63414653/how-to-prevent-automatic-file-eviction-in-icloud-documents).
  - Developers report `NSMetadataQuery` missing updates for Finder edits and for non-root directories, so periodic rescans are a necessary fallback — [Apple Dev Forums 664089](https://developer.apple.com/forums/thread/664089); [Open Radar 29880025](https://openradar.appspot.com/29880025).

### Inferences
- **Architecture:**
  - The vault folder is the source of truth.
  - `index.sqlite` lives in `~/Library/Application Support/<app>/<vault-id>/`, not inside the vault, so it never syncs or conflicts. It can be deleted and rebuilt at any time.
  - Each file row stores `path, mtime, size, content_hash (xxHash/SHA256), parsed_at`. Reconcile on launch with a cheap stat walk, then re-parse only files whose hash changed.
- **Suggested schema (GRDB records):**
  - `notes(id, path UNIQUE, title, mtime, size, hash, created, modified)`
  - `properties(note_id, key, value_text, value_num, value_date)` stores YAML frontmatter EAV-style, with indexes on `(key, value_*)`.
  - `tags(note_id, tag)`
  - `links(src_note_id, target_text, target_note_id NULL, kind[wikilink|md|embed], anchor_heading, anchor_block, line, col)` keeps unresolved links so they resolve when a target appears.
  - `headings`
  - `blocks(note_id, block_id, kind, start_line, end_line, text, hash)`
  - `notes_fts` and `blocks_fts` as FTS5 external-content tables (tokenizer `unicode61 remove_diacritics 2`, or `trigram` for substring search).
  - `chunks_vec` (sqlite-vec `vec0`) keyed to `blocks`.
  - `attachments(path, kind, hash)` for PDFs and images.
- **GRDB features to use:** `DatabasePool` in WAL mode (concurrent reads while an indexer writes), `ValueObservation` to drive SwiftUI lists, and `DatabaseMigrator`. Bump a schema version and simply rebuild rather than migrate cache data.
- **Do not use** SwiftData or Core Data for the index. They duplicate the truth, have heavier change tracking, offer no first-class FTS5, and SwiftData has scaling concerns. Use SQLiteData only if CloudKit-synced app state, such as UI preferences, is ever needed.
- **File watching:**
  - Use the FSEvents C API (`FSEventStreamCreate` with `kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes`) on the vault root, persisting the last `FSEventStreamEventId` so changes made while the app was closed are replayed on launch.
  - `DispatchSource.makeFileSystemObjectSource` watches one file descriptor at a time and doesn't scale to 100k files. Use it only for the currently open document, if at all.
  - Debounce events by about 100–300 ms and coalesce per path.
  - Treat atomic save patterns (write temp, then rename) used by Obsidian, git checkouts, and agents as delete+create pairs, and resolve them by path and hash.
  - The app's own writes should go through `NSFileCoordinator` and be tagged with their written hash in memory, so the echoed FSEvent is ignored.
- **External edits while a note is open:** If the buffer is clean, reload silently. If it is dirty, show a merge or keep-mine banner, using a three-way merge against the last-saved hash.
- **iCloud Drive vaults:** Treat files as possibly dataless. Check `URLResourceValues.ubiquitousItemDownloadingStatus` before parsing, and request downloads lazily. Never resolve links by following symlinks.

### Gaps
- I didn't verify whether iCloud Drive on current macOS (Sonoma and later use the File Provider-based iCloud Drive) still produces `.icloud` stub files or only "dataless" files with the original name. The `.icloud` stub behavior is documented for older systems and iOS. Test this on macOS 26/27 before relying on either.
- I found no authoritative 2025–2026 benchmark of FTS5 or sqlite-vec at 100k notes from Swift.
- Whether system `libsqlite3` permits `sqlite3_load_extension` in a Developer ID app on macOS 26/27 wasn't verified. The community packages sidestep it by bundling SQLite.
- I found no WWDC26 changes to SwiftData or Core Data. The WWDC26 macOS guide lists none — [Apple WWDC26 macOS guide](https://developer.apple.com/wwdc26/guides/macos/).

## PDFs: PDFKit capabilities and limits, alternatives, structured text extraction

### Takeaway
PDFKit is free and built in, and it covers viewing, text extraction, search, selection, and reading and writing standard annotations such as highlights. It is enough for a personal reading and highlighting workflow, with highlights extracted to Markdown. Nutrient (formerly PSPDFKit) is far more capable, but it is enterprise-priced and its macOS roadmap is uncertain, so it is a poor fit for a personal app.

### Cited Findings
- Nutrient's own migration guide calls Apple PDFKit "a great starting point" and the easiest to integrate because it is a system library. It notes that PDFKit exposes a single `PDFAnnotation` class (plus `PDFBorder`), while Nutrient supports every annotation type in the PDF specification with a richer API. This is vendor framing — [Nutrient "Migrating from Apple PDFKit"](https://www.nutrient.io/guides/macos/migration-guides/migrating-from-apple-pdfkit/).
- Nutrient's macOS SDK is "bring your own views," with no ready-made viewer, and Nutrient says it is "in the process of defining the roadmap" for macOS — [Nutrient "Where to go from here"](https://www.nutrient.io/guides/macos/getting-started/where-to-go-from-here); [Nutrient blog](https://nutrient.io/blog/pspdfkit-for-macos).
- Pricing isn't published. Capterra lists a starting price of €5,000, per user — [Capterra](https://www.capterra.com/p/171174/PSPDFKit-SDK/pricing/). A competitor claims an average of about $76K a year, which is unverified and biased — [PDFluent](https://pdfluent-playground.pages.dev/comparison/vs-nutrient).
- WWDC26 announced no PDFKit changes — [Apple WWDC26 macOS guide](https://developer.apple.com/wwdc26/guides/macos/).
- WWDC26's Foundation Models update includes "Vision tools (OCR, barcodes)" usable from the on-device model. That is relevant for scanned PDFs, but belongs to the AI layer — [Apple WWDC26 macOS guide](https://developer.apple.com/wwdc26/guides/macos/).

### Inferences
- **What PDFKit provides** (Apple docs: [PDFKit](https://developer.apple.com/documentation/pdfkit), [PDFAnnotation](https://developer.apple.com/documentation/pdfkit/pdfannotation)):
  - `PDFView` for display
  - `PDFDocument.string` and `PDFPage.string`/`attributedString` for text
  - `PDFDocument.findString`, plus `PDFSelection` with per-line bounds
  - `PDFAnnotation` subtypes `.highlight`, `.underline`, `.strikeOut`, `.text`, `.freeText`, and `.ink`, read and written through `page.annotations` and `addAnnotation`, saved with `PDFDocument.write(to:)`
  - The outline (`PDFOutline`)
  
  Highlights written this way are standard PDF annotations, so they round-trip with Preview, Zotero, and other readers.
- **Weak spots:**
  - Text extraction gives no reliable reading order for multi-column papers, no structure for tables, figures, or headings, and no math.
  - Scanned PDFs need OCR (the Vision framework's `VNRecognizeTextRequest` or the newer Swift Vision API).
  - Saving through `PDFDocument.write` rewrites the file and occasionally drops or alters incremental-save content. Write annotations to a copy, or keep a sidecar Markdown highlight file as the canonical record ("file over app").
- **For structured extraction** (headings, columns, tables), shell out to a local tool from a helper, such as `pdftotext -layout`, or an ML layout parser covered by the AI researcher. PDFKit alone won't recover document structure.
- **Pattern:** keep the PDF in the vault's `attachments/` folder plus a companion note (`paper.pdf.md`, or a note with `source: [[paper.pdf]]` frontmatter) holding extracted highlights as blocks with page anchors (`#page=5`), and index those highlights like any other block.

### Gaps
- I did not fetch Apple's PDFKit documentation pages this session. The API list above comes from background knowledge and should be re-checked.
- I found no concrete source on PDFKit annotation round-trip fidelity issues on macOS 26/27.

## Capture: Share Extension, Safari Web Extension, Services, global hotkey panel, App Intents/Shortcuts, URL schemes, drag-and-drop, clipboard, web page to Markdown

### Takeaway
Every capture path should end in one Swift "capture service" that writes a Markdown file with frontmatter into an `Inbox/` folder. Clipping web pages to Markdown is a solved problem with **Defuddle** (Obsidian's own, MIT-licensed Readability successor). Run it in a hidden `WKWebView` on the live DOM, or in the Safari Web Extension's content script, then convert to Markdown.

### Cited Findings
- **Defuddle,** by Steph Ango (kepano, Obsidian CEO):
  - It takes a URL or HTML and returns cleaned HTML or Markdown.
  - It was created because Mozilla Readability "appears to be mostly abandoned."
  - It removes fewer uncertain elements than Readability and standardizes footnotes, math (MathML/LaTeX), code blocks, and callouts.
  - A CLI is available: `npx defuddle parse <url> --markdown`.
  
  Sources: [defuddle GitHub](https://github.com/kepano/defuddle); [stephango.com/defuddle](https://stephango.com/defuddle); [Show HN](https://hnews-reader.vercel.app/show/44067409). It is reported to power the Obsidian Web Clipper, but that is unverified in the sources found.
- **Safari Web Extensions:** WWDC26 notes that Xcode Cloud can now build and test a Safari web extension without a Mac (WebKit session 204) — [Apple WWDC26 macOS guide](https://developer.apple.com/wwdc26/guides/macos/).
- **App Intents** (macOS 26+): actions exposed through App Intents appear in both Shortcuts and **Spotlight on Mac**, which can run app actions directly. Spotlight also gained "Quick Keys," short strings that trigger frequent actions — [Apple WWDC25 session 260](https://developer.apple.com/videos/play/wwdc2025/260?time=76); [WWDC Notes 260](https://wwdcnotes.com/documentation/wwdc25-260-develop-for-shortcuts-and-spotlight-with-app-intents/); [MacRumors](https://www.macrumors.com/2025/06/09/apple-supercharges-spotlight-in-macos-tahoe-with-quick-keys-and-more/); [TechCrunch](https://techcrunch.com/2025/06/09/apple-updates-spotlight-to-take-actions-on-your-mac/).
- MarkEdit shows a native app can keep **system Services** and **Shortcuts** for text processing while its editor is web-based — [MarkEdit wiki](https://github.com/MarkEdit-app/MarkEdit/wiki/Why-MarkEdit).

### Inferences
- **Capture surfaces, in priority order for a personal app:**
  1. **App Intent "Capture Note" / "Clip URL"** with `String`, `URL`, and file parameters. One implementation serves Shortcuts, Spotlight actions (macOS 26+), Siri, and Quick Keys.
  2. **Global-hotkey quick-capture panel:** a floating `NSPanel` (`.nonactivatingPanel`) hosting a SwiftUI view, triggered by a global shortcut. The `KeyboardShortcuts` package (sindresorhus) is the common choice. Prefill it from the frontmost app's selection or the clipboard (`NSPasteboard`).
  3. **Safari Web Extension** (Swift container app + JS content script). Run Defuddle in the content script on the live, logged-in DOM, then send `{url, title, html/markdown, selection}` to the native app via `browser.runtime.sendNativeMessage` (handled by `SafariWebExtensionHandler` / `NSExtensionRequestHandling`). This captures paywalled or JS-rendered pages that a URL fetch would miss.
  4. **Share Extension** (`NSExtensionPointIdentifier com.apple.share-services`) for URLs, text, and files from any app's Share menu. Extensions are sandboxed, so write through a shared App Group container or hand off to the main app via URL scheme or XPC.
  5. **Services menu** (`NSServices` in Info.plist, "Send selection to KB").
  6. **URL scheme** (`kb://capture?title=…&body=…`), for scripting and for parity with Obsidian's `obsidian://` URIs. Don't put sensitive content in URLs.
  7. **Drag-and-drop** onto the window or a menu-bar drop target (`.dropDestination(for:)`, plus `.onDragSessionUpdated` on macOS 27, reported as already present in 26 — [pfandrade](https://pfandrade.me/blog/swiftui-mac-assed-wwdc26-update/)).
- **Turning a URL into Markdown without the browser:** load it into an offscreen `WKWebView`, inject the bundled `defuddle` JS bundle, and call `evaluateJavaScript`. Defuddle needs a DOM, so JavaScriptCore alone isn't enough without a DOM shim. Store `source`, `clipped`, `author`, and `published` in YAML frontmatter, matching Obsidian Web Clipper conventions for interoperability.
- **Alternative for personal use:** simply install the official Obsidian Web Clipper extension pointed at the same vault, since the vault is Obsidian-compatible. That avoids building a Safari extension at all.

### Gaps
- I didn't verify the macOS 26/27 specifics of Share Extension and Safari Web Extension native messaging. The APIs are long-standing, but no 2026 source was fetched.
- No source confirmed that Defuddle runs well inside JavaScriptCore without a DOM, so the inference is to use WKWebView.

## System integration: Core Spotlight, Quick Look, App Intents (macOS 26/27), menu bar extra, widgets

### Takeaway
Use **App Intents + App Entities** as the integration backbone. In macOS 26 they power Shortcuts, Spotlight actions, and Siri. In macOS 27 they also feed Siri's semantic index through new entity and intent schemas, plus an `AppIntentsTesting` framework. Add Core Spotlight indexing of notes (linked to entities), a `MenuBarExtra` for capture, and widgets that are configurable through App Intents.

### Cited Findings
- **macOS 26 (WWDC25 session 260):** App Intents are the app's "verbs" and App Entities its "nouns." Adopting them makes actions available in Shortcuts and Spotlight on Mac with the same process — [WWDC Notes 260](https://wwdcnotes.com/documentation/wwdc25-260-develop-for-shortcuts-and-spotlight-with-app-intents/); [Apple session 260](https://developer.apple.com/videos/play/wwdc2025/260?time=134). Spotlight in Tahoe exposes "hundreds" of actions, with developer actions added via App Intents — [9to5Mac](https://9to5mac.com/?p=1005466).
- **macOS 27 (WWDC26)** — [Apple WWDC26 macOS guide](https://developer.apple.com/wwdc26/guides/macos/):
  - **Entity schemas** contribute app content to the Spotlight semantic index so Siri can surface it with attribution.
  - **Intent schemas** let people act on content with no predefined phrases.
  - The **View Annotations API** maps views to entities so people can act on what's on screen conversationally.
  - The **AppIntentsTesting** framework validates integrations through system pathways without UI automation.
  - Sessions: 344 "Code-along: Make your app available to Siri," 240 "Build intelligent Siri experiences with App Schemas," 343, 345 "Discover new capabilities in the App Intents framework," 295 "Validate your App Intents adoption with AppIntentsTesting," and 246 "LLM search using Core Spotlight."
  - macOS 27 includes a standalone Siri app — [Neowin](https://www.neowin.net/amp/macos-golden-gate-unveiled-with-standalone-siri-app-performance-improvements-and-more/).
- **WidgetKit (macOS 27):** widgets can be customized through App Intents and dynamic styling (session 277 "WidgetKit foundations") — [Apple WWDC26 macOS guide](https://developer.apple.com/wwdc26/guides/macos/).
- **Quick Look:** the only WWDC26 Quick Look item was a Spatial Preview framework for visionOS, which isn't relevant here — [Apple WWDC26 macOS guide](https://developer.apple.com/wwdc26/guides/macos/).

### Inferences
- **Core Spotlight:** index each note as a `CSSearchableItem` (title, snippet, tags, path), associated with the note's `AppEntity` (`associateAppEntity`, available since iOS 18/macOS 15). System Spotlight then finds notes, Siri can reference them, and macOS 27 entity schemas build on the same entities. Re-index incrementally from the same pipeline that updates SQLite. Use `CSSearchableIndex` batch APIs with a client state token for resumable reindexing.
- Session 246 ("LLM search using Core Spotlight") suggests the system index may double as a semantic search backend. Hand this to the AI-layer researcher.
- **Quick Look:** `.md` files already preview as plain text. A Quick Look Preview Extension (`QLPreviewingController`) could render styled Markdown in Finder, but this is low priority.
- **Menu bar:** SwiftUI `MenuBarExtra` (`.window` style) for quick capture, recent notes, and the inbox count. It pairs with the global hotkey panel.
- **Prefer App Intents over SiriKit or AppleScript** for automation. App Intents are discoverable by Shortcuts, Spotlight, and Siri, and testable with AppIntentsTesting on macOS 27.

### Gaps
- I didn't fetch session 246 or session 345 for exact API names. The "entity schema" and "intent schema" APIs need verification against the macOS 27 SDK docs.
- I found no 2026 source on Quick Look extension changes for Markdown.

## Sync and backup: iCloud Drive vs CloudKit vs git; libgit2/SwiftGit2 vs shelling out to git; iOS companion

### Takeaway
For a file-over-app vault, **sync the files, not a database**. iCloud Drive folder sync works, as FSNotes and Obsidian-on-iCloud users show, but brings eviction and placeholder headaches and occasional conflict copies. Git gives real history and is agent-friendly. For a personal app, use **git auto-commit by shelling out to `/usr/bin/git`** (or a bundled git) from a non-sandboxed, Developer ID app. Make iCloud Drive optional for the future iOS companion. CloudKit would only make sense for app state, not notes.

### Cited Findings
- FSNotes syncs plain-file notes through iCloud Drive or Dropbox on macOS, uses iCloud Drive on iOS, and offers optional git versioning and backups — a working Swift precedent — [FSNotes GitHub](https://GitHub.com/glushchenko/fsnotes).
- iCloud Drive eviction creates placeholders and breaks links to evicted files — [mjtsai](https://mjtsai.com/blog/wp-json/wp/v2/posts/21443). `NSMetadataQuery` update notifications are unreliable in some cases — [Apple Dev Forums 664089](https://developer.apple.com/forums/thread/664089).
- iCloud files are only visible in Files/iCloud Drive when they sit under the container's `Documents/` folder — [iCloud Storage Plus docs](https://pub.dev/documentation/icloud_storage_plus/latest).
- Point-Free's SQLiteData provides CloudKit sync on top of GRDB, if a structured synced store is ever needed — [sqlite-data](https://github.com/pointfreeco/sqlite-data).

### Inferences
- **Recommended:** keep the vault as a local folder that is also a git repo.
  - Auto-commit on idle (for example 5 minutes after the last change) and on quit with a generated message such as "auto: 12 notes changed."
  - Optionally push to a private remote.
  - Shelling out via `Process` is simpler and more robust than embedding libgit2. SwiftGit2 has historically lagged libgit2 releases and adds build complexity, and its maintenance status should be checked before use.
  - Git also gives agents (Claude Code and others) a safe edit-and-review workflow on the same vault.
- **Avoid running iCloud Drive and git on the same folder.** `.git` internals get evicted and conflicted. If iOS access is needed later, sync the working tree via iCloud Drive, keep the git repo elsewhere (or use `--separate-git-dir`), or use the Obsidian/Working Copy model on iOS.
- **CloudKit** (`CKSyncEngine`, or SQLiteData) is the wrong layer for Markdown files but fine for small app-state sync, such as saved searches and UI layout, later.

### Gaps
- I didn't verify the current maintenance status of SwiftGit2 or any 2026 Swift libgit2 wrapper.
- I found no 2026 data on iCloud Drive reliability for large Markdown vaults (10k+ files).

## Distribution for personal use: Developer ID + notarization vs App Store sandbox; unsigned local builds; Xcode vs SwiftPM; building with agents (XcodeBuildMCP, Xcode MCP)

### Takeaway
For one person's Mac, **skip the Mac App Store and the App Sandbox**. Build with Xcode (an `.xcodeproj`, ideally generated by XcodeGen or Tuist, or a lean Xcode project plus local SwiftPM packages for the core logic). Run locally with "Sign to Run Locally" or a free personal team, and add Developer ID + notarization only if it will ever run on another Mac. Agents can drive builds through Xcode's native MCP bridge (`xcrun mcpbridge`, Xcode 26.3+) or **XcodeBuildMCP**.

### Cited Findings
- **Xcode 26.3** added agentic coding with Anthropic's Claude Agent and OpenAI Codex inside the IDE. Agents can search docs, explore files, update project settings, and capture Previews, and Xcode exposes these capabilities over MCP to outside agents — [TechRadar](https://www.techradar.com/pro/apple-launches-xcode-26-3-brings-even-more-ai-power-to-coding-on-mac); [SD Times](https://sdtimes.com/ai/xcode-26-3-adds-agentic-coding-support/); [InfoQ](https://infoq.com/news/2026/02/xcode-26-3-agentic-coding).
- External clients connect through `xcrun mcpbridge`, which bridges MCP to XPC with a running Xcode. Example: `claude mcp add --transport stdio xcode -- xcrun mcpbridge` — [DEV Community](https://dev.to/arshtechpro/xcode-263-use-ai-agents-from-cursor-claude-code-beyond-4dmi). One write-up counts about 20 tools (file operations, builds, preview rendering) — [OpenClaw Hub](https://openclaw-hub.pages.dev/blog/xcode-mcp-expression-surgery). An RC build had a missing-`structuredContent` bug, so use the GA release — [Codex CLI guide](https://codex.danielvaughan.com/2026/03/28/codex-cli-mobile-xcode-ios-android/).
- **XcodeBuildMCP** (now under getsentry):
  - An MCP server and CLI for building, running, and testing iOS and macOS projects.
  - Requires macOS 14.5+, Xcode 16+, and Node 18+. The Homebrew install requires Xcode 26.3+.
  - Install with `claude mcp add XcodeBuildMCP -- npx -y xcodebuildmcp@latest mcp`.
  - Sends Sentry telemetry by default, with an opt-out.
  
  Sources: [lobehub listing](https://lobehub.com/es/mcp/getsentry-xcodebuildmcp); [czottmann fork](https://github.com/czottmann/XcodeBuildMCP).
- **Xcode 27 (WWDC26)** ships agent skills ("SwiftUI Specialist," "What's New in SwiftUI") in its Coding Assistant. Sessions: 259 "Xcode, agents, and you" and 258 "What's new in Xcode 27" — [Apple WWDC26 SwiftUI guide](https://developer.apple.com/wwdc26/guides/swiftui/); [WWDC26 SwiftUI search summaries](https://swiftwithmajid.com/2026/06/08/what-is-new-in-swiftui-after-wwdc26/).
- Xcode 27 build times improve through the ViewBuilder → `ContentBuilder` change — [Apple WWDC26 SwiftUI guide](https://developer.apple.com/wwdc26/guides/swiftui/).

### Inferences
- **Sandbox tradeoff:** an App Store app must be sandboxed. Vault folder access then needs `NSOpenPanel` plus **security-scoped bookmarks** (`URL.bookmarkData(options: .withSecurityScope)` and `startAccessingSecurityScopedResource()`), shelling out to `git` or `pdftotext` is blocked or awkward, and FSEvents on user folders works only inside the granted scope.
  - A non-sandboxed Developer ID app avoids all of this.
  - Extensions (Share, Safari, widgets) are always sandboxed, so use an **App Group** container for handoff even in a Developer ID app.
  - Developer ID needs the $99/year Apple Developer Program. A free Apple ID "Personal Team" can sign locally but has profile and extension limits, and app extensions and some capabilities need a paid account. Unverified detail; check.
- **SwiftPM-only:** a pure `swift build` executable can produce a Mac app only with manual bundle assembly. Extensions, entitlements, App Intents metadata extraction, and asset catalogs are far easier in Xcode. Recommended layout: a thin Xcode app target plus local Swift packages (`KBCore` for parsing, index, and file watching; `KBCapture`; `KBUI`) that agents can build and test quickly with `swift test`, independent of Xcode.
- **For agent-heavy development:**
  - Generate the project with XcodeGen or Tuist from a YAML or Swift manifest, so agents never hand-edit `project.pbxproj`.
  - Use XcodeBuildMCP or `xcrun mcpbridge` for build-run-screenshot loops.
  - Keep most logic in SwiftPM packages with unit tests.

### Gaps
- I couldn't fetch details of WWDC26 session 259 or the specifics of Xcode 27's agent and MCP surface.
- Free Personal Team limits for macOS app extensions and App Groups in 2026 weren't verified.

## Architecture patterns: Observation, TCA or not, performance at 10k–100k files, multi-window, command palette

### Takeaway
Use plain SwiftUI with the **Observation framework** (`@Observable` models plus `@Environment` injection), actors for background indexing, and GRDB `ValueObservation` streams feeding view models. Skip TCA for a solo, agent-built personal app. Keep large collections in SQLite and query them lazily, not in memory, and use AppKit where SwiftUI is still weak (the editor, complex outline or list behaviors).

### Cited Findings
- **WWDC26 SwiftUI changes** (macOS 27+) — [Apple WWDC26 SwiftUI guide](https://developer.apple.com/wwdc26/guides/swiftui/):
  - `@State` became a macro, and classes in `@State` initialize lazily, once per view lifetime.
  - `ViewBuilder` became `ContentBuilder`, for faster builds.
  - Reorderable container APIs work across `List`, `LazyVGrid`, and others.
  - Toolbar APIs `visibilityPriority`, `toolbarOverflowMenu`, and `topBarPinnedTrailing`.
  - A new document API, `ReadableDocument`/`WritableDocument`, with asynchronous, incremental disk I/O and `Subprogress` progress reporting, plus `DocumentCreationSource`/`NewDocumentButton`.
  - Session 321 "Dive into lazy stacks and scrolling with SwiftUI."
- **Remaining SwiftUI-on-Mac gaps (after WWDC26):**
  - Custom selection and focus outside `List`/`Table` still has to be tracked by hand.
  - SwiftUI can't tell whether a context menu is open (FB23097100).
  - Toolbar ergonomics need work.
  - New: `.onDragSessionUpdated`, `.reorderable`, and `\.backgroundProminence`.
  
  Source: [Paulo Andrade, "Mac-assed App with SwiftUI, WWDC26 update"](https://pfandrade.me/blog/swiftui-mac-assed-wwdc26-update/).
- SwiftData read performance degraded sharply above about 100k objects in a 2024 comparison, which reinforces keeping big data in SQLite — [Reddit/Emerge summary](https://cal1.lr.ggtyler.dev/r/iOSProgramming/comments/1dkmdeb/swiftdata_vs_realm_performance_comparison).

### Inferences
- **App structure:**
  - Use a `WindowGroup(for: VaultID.self)` or `DocumentGroup` per vault. The new macOS 27 document API is designed for single-file documents, while a vault is a folder, so a custom `WindowGroup` with a vault model is likely a better fit.
  - Use `NavigationSplitView` (sidebar file tree / note list / editor) with `openWindow(value: noteID)` for multi-window note pop-outs.
  - Expose one shared `VaultStore` (`@Observable`, `@MainActor`) per vault, an `actor Indexer` (parsing, FTS, embeddings), an `actor FileWatcher`, and the GRDB `DatabasePool` underneath.
- **Scaling to 100k files:**
  - Never load all notes into `@Observable` arrays. Use SQL-backed paged queries and `List`/`Table` with stable IDs.
  - Index on a background actor with batched transactions of about 500–1000 files per transaction.
  - Hash-based skipping makes warm launches near instant.
  - Parse in a `TaskGroup` bounded to the number of performance cores.
  - FTS5 queries return in milliseconds at this scale (general SQLite experience, not verified here).
- **Command palette:** a `.sheet` or floating `NSPanel` with a `TextField` that fuzzy-matches against `commands` (registered from your `Commands` and App Intents) and note titles (FTS5 prefix or trigram query). Bind it to ⌘K / ⌘P via `.keyboardShortcut` in `CommandMenu`. Reusing the App Intents definitions as palette commands keeps one source of actions.
- **Skip TCA.** It adds boilerplate and a learning curve that agents handle inconsistently. Observation plus actors is Apple's default path and what WWDC26 tooling (Xcode 27's SwiftUI agent skills) is tuned for.

### Gaps
- I found no published case study of a SwiftUI app at 100k notes with measured numbers.
- Session 321's lazy stack and scrolling guidance wasn't fetched.

## Reference open-source Mac apps of similar shape

### Takeaway
No open-source Swift app matches "Obsidian-compatible vault + SQLite index + PDF + clipping" exactly. Study **MarkEdit** (editor architecture), **FSNotes** (plain-file notes, iCloud, git, wikilinks in Swift), **CotEditor** (native NSTextView editor at scale), and **STTextView** (TextKit 2 internals). For the index layer, look at **Point-Free SQLiteData** and GRDB's own demo apps.

### Cited Findings
- **MarkEdit:** Swift/AppKit plus CodeMirror 6, MIT, actively reviewed in 2026 — [GitHub](https://github.com/MarkEdit-app/MarkEdit); [brycewray 2026](https://brycewray.com/posts/2026/06/markedit-textedit-markdown/).
- **FSNotes:** Swift, MIT, files on disk, iCloud Drive or Dropbox, optional git, `[[wikilinks]]`, Mermaid, MathJax, AES-256 encryption, macOS and iOS — [GitHub](https://GitHub.com/glushchenko/fsnotes).
- **STTextView:** a TextKit 2 `NSTextView` replacement with line numbers, including documented workarounds for TextKit 2 bugs — [GitHub](https://www.github.com/krzyzanowskim/STTextView).
- **SQLiteData:** a GRDB-based SwiftData alternative with CloudKit sync — [GitHub](https://github.com/pointfreeco/sqlite-data).
- **Defuddle:** reference implementation for web-to-Markdown clipping — [GitHub](https://github.com/kepano/defuddle).
- Newer small Markdown editor repos surfaced in search but weren't evaluated: [joshdpowell/clearly](https://github.com/joshdpowell/clearly), [xronocode/mark](https://github.com/xronocode/mark).
- **CotEditor:** [GitHub](https://github.com/coteditor/CotEditor) (not fetched this session).

### Inferences
- Combining MarkEdit's editor approach, FSNotes' file and sync model, and GRDB/SQLiteData's index layer covers about 80% of the architecture.
- Obsidian itself, which is closed-source Electron, sets the interop contract: `[[wikilinks]]`, `![[embeds]]`, `^block-ids`, YAML properties, and `.obsidian/` config. The Swift app should read those conventions, never write `.obsidian/`, and leave its own state outside the vault.

### Gaps
- No well-known open-source *Swift* knowledge-base app with backlinks, a graph, and a SQLite index surfaced in search. The FSNotes internals (index or storage) weren't inspected.
- CotEditor's current architecture (TextKit 1 vs 2 on macOS 26/27) wasn't verified.
