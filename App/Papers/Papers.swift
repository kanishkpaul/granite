import Foundation
import KBCore
import KBIndex
import KBPapers

/// Where an open PDF window should go next (set by links, search hits and answers).
struct PDFNavigation: Equatable {
    var page: Int
    var block: String?
    /// Text to find and mark on that page, when there is no highlight block (search hits, quotes).
    var find: String?
    /// Changes on every request, so asking for the same place twice still scrolls there.
    var nonce = UUID()
}

/// Papers in the app: import PDFs, open the PDF view, and keep highlights in the literature note.
extension VaultStore {
    /// Imports PDFs (⌘K "Import PDF…", drag and drop). Opens the literature note of the last one.
    func importPDFs(_ urls: [URL]) async {
        guard let vault, let writer else { return }
        let importer = PaperImporter(vault: vault, writer: writer)
        var imported: [PaperImportResult] = []
        var problems: [String] = []
        for url in urls where url.pathExtension.lowercased() == "pdf" {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                imported.append(try await importer.importPDF(at: url))
            } catch {
                problems.append("\(url.lastPathComponent): \(error)")
            }
        }
        if !imported.isEmpty { _ = try? await indexer?.update(paths: imported.flatMap(\.written).filter { $0.hasSuffix(".md") }) }
        refreshLists()
        if let last = imported.last { openNote(last.paths.note) }
        let ocr = imported.filter(\.ocr).count
        status = problems.isEmpty
            ? "Imported \(imported.count) paper(s)\(ocr > 0 ? ", \(ocr) by OCR" : "")."
            : "Imported \(imported.count); " + problems.joined(separator: "; ")
    }

    /// Opens (or brings forward) the PDF window for `path` at a page, marking a highlight or text.
    func openPDF(_ path: String, page: Int = 1, block: String? = nil, find: String? = nil) {
        pdfNavigation[path] = PDFNavigation(page: page, block: block, find: find)
        pdfRequest = path
    }

    /// The PDF for a literature note, its text note, or a PDF path.
    func pdfPath(for path: String) -> String? {
        if path.lowercased().hasSuffix(".pdf") { return path }
        if let citekey = PaperPaths.citekey(of: path) { return PaperPaths(citekey: citekey).pdf }
        guard let vault, let data = try? Data(contentsOf: vault.url(for: path)) else { return nil }
        return MarkdownDocument(text: String(decoding: data, as: UTF8.self)).frontmatter?["pdf"]?.text
    }

    /// Search hits and cited passages in a paper's full text open the PDF at that page.
    func openPaperPassage(path: String, headingPath: String, text: String) -> Bool {
        guard path.hasPrefix("Papers/text/"), let pdf = pdfPath(for: path) else { return false }
        let words = text.split(whereSeparator: \.isWhitespace).prefix(8).joined(separator: " ")
        // Docling text has no page sections: page 0 makes the PDF view search every page.
        openPDF(pdf, page: PaperText.page(fromHeadingPath: headingPath) ?? 0, find: words)
        return true
    }

    /// A cited passage: the note at its line and, for a paper's full text, the PDF at the quote.
    func openCited(_ hit: HybridHit, quote: String?) {
        openNote(hit.path, line: hit.startLine)
        _ = openPaperPassage(path: hit.path, headingPath: hit.headingPath, text: quote ?? hit.text)
    }

    /// The literature note for the open note (the note itself, its full text, or its PDF).
    var openPaperNote: String? {
        guard let path = openPath else { return nil }
        if let citekey = PaperPaths.citekey(of: path) { return PaperPaths(citekey: citekey).note }
        return pdfPath(for: path).flatMap { literatureNotePath(forPDF: $0) }
    }

    /// Looks the open paper up in Crossref, OpenAlex and Semantic Scholar (by DOI, else title).
    func enrichOpenPaper() async {
        guard let note = openPaperNote, let vault, let writer,
              let text = try? String(contentsOf: vault.url(for: note), encoding: .utf8) else { return }
        let frontmatter = MarkdownDocument(text: text).frontmatter
        status = "Looking the paper up…"
        do {
            let record = try await ScholarlyClient().lookup(doi: frontmatter?["doi"]?.text, title: frontmatter?["title"]?.text)
            let updated = try EnrichmentWriter.apply(record, to: text, date: ClaimDay.string(Date()))
            try await writer.write(updated, to: note, as: .user)
            _ = try await indexer?.update(paths: [note])
            status = "Enriched \(NoteParser.title(for: note))" + (record.citedBy.map { " · cited by \($0)" } ?? "")
            refreshInspector()
        } catch {
            status = "Could not enrich: \(error)"
        }
    }

    var doclingInstalled: Bool { DoclingRunner.locate() != nil }

    /// References and citing works of the open paper, ranked by closeness to your notes, written
    /// to `AI/Reading/<citekey> graph.md`.
    func expandLiteratureGraph() async {
        guard let note = openPaperNote, let vault, let writer, let database, let citekey = PaperPaths.citekey(of: note),
              let text = try? String(contentsOf: vault.url(for: note), encoding: .utf8) else {
            status = "Open a paper's note first."
            return
        }
        let frontmatter = MarkdownDocument(text: text).frontmatter
        let searcher = semantic.hasVectors ? semantic.searcher : nil
        let scorer: LiteratureGraph.Scorer = { text in
            if let embedder = searcher?.embedder, let vectors = searcher?.vectors,
               let vector = try? await embedder.embed(documents: [text]).first,
               let nearest = try? await vectors.nearest(vector, k: 8) {
                // The seed's own note and text would always win; the point is your other notes.
                for match in nearest {
                    guard let path = try? database.path(ofChunk: match.chunk), PaperPaths.citekey(of: path) != citekey,
                          !path.hasPrefix("AI/") else { continue }
                    return (Double(match.score), path)
                }
                return nil
            }
            // Without vectors: does a keyword search over your notes find anything?
            let words = text.split(whereSeparator: { !$0.isLetter }).filter { $0.count > 4 }.prefix(6).joined(separator: " ")
            guard !words.isEmpty, let hit = try? database.search(words, options: SearchOptions(limit: 1)).first else { return nil }
            return (0.5, hit.path)
        }
        status = "Asking OpenAlex about \(citekey)…"
        do {
            let (seed, candidates) = try await LiteratureGraph().expand(seedID: frontmatter?["openalex"]?.text, doi: frontmatter?["doi"]?.text,
                                                                        knownDOIs: (try? database.knownDOIs()) ?? [], scorer: scorer)
            let path = "AI/Reading/\(citekey) graph.md"
            try await writer.write(LiteratureGraph.render(seedTitle: seed.title ?? citekey, citekey: citekey, candidates: candidates,
                                                          date: ClaimDay.string(Date())), to: path, as: .ai)
            _ = try await indexer?.update(paths: [path])
            status = "\(candidates.count) papers around \(citekey)"
            openNote(path)
        } catch {
            status = "Could not expand: \(error)"
        }
    }

    /// "Study with Docling": structured text (sections, tables) replaces the page text.
    func studyOpenPaper() async {
        guard let note = openPaperNote, let vault, let writer, let citekey = PaperPaths.citekey(of: note) else { return }
        guard let executable = DoclingRunner.locate() else {
            status = DoclingError.notInstalled.description
            return
        }
        let paths = PaperPaths(citekey: citekey)
        status = "Docling is reading \(citekey)… (minutes for long papers)"
        do {
            let runner = DoclingRunner(executable: executable, cache: vault.supportDirectory.appending(path: "docling"))
            let markdown = try await runner.markdown(pdf: vault.url(for: paths.pdf), citekey: citekey)
            let title = (try? database?.note(path: note))??.title ?? citekey
            try await writer.write(DoclingRunner.textNote(paths: paths, title: title, markdown: markdown), to: paths.text, as: .user)
            if let text = try? String(contentsOf: vault.url(for: note), encoding: .utf8) {
                try await writer.write(try FrontmatterEditor.setScalar("status", to: "studied", in: text), to: note, as: .user)
            }
            _ = try await indexer?.update(paths: [paths.text, note])
            status = "Structured text ready for \(citekey)"
        } catch {
            status = "\(error)"
        }
    }

    func literatureNotePath(forPDF pdf: String) -> String? {
        PaperPaths.citekey(of: pdf).map { PaperPaths(citekey: $0).note }
    }

    func highlights(forPDF pdf: String) -> [Highlight] {
        guard let vault, let note = literatureNotePath(forPDF: pdf),
              let text = try? String(contentsOf: vault.url(for: note), encoding: .utf8) else { return [] }
        return LiteratureNote.highlights(in: text)
    }

    /// Adds a highlight to the literature note's managed region (your action, so written as you).
    func addHighlight(_ highlight: Highlight, toPDF pdf: String) async {
        guard let vault, let writer, let note = literatureNotePath(forPDF: pdf) else { return }
        let current = (try? String(contentsOf: vault.url(for: note), encoding: .utf8))
            ?? "# \(PaperPaths.citekey(of: pdf) ?? "Paper")\n"
        do {
            try await writer.write(LiteratureNote.upsert(highlight, in: current, pdfPath: pdf), to: note, as: .user)
            _ = try await indexer?.update(paths: [note])
            status = "Highlighted on p. \(highlight.page) → \(note)"
        } catch {
            status = "Could not save the highlight: \(error)"
        }
    }

    func removeHighlight(id: String, fromPDF pdf: String) async {
        guard let vault, let writer, let note = literatureNotePath(forPDF: pdf),
              let current = try? String(contentsOf: vault.url(for: note), encoding: .utf8) else { return }
        try? await writer.write(LiteratureNote.remove(id: id, in: current, pdfPath: pdf), to: note, as: .user)
        _ = try? await indexer?.update(paths: [note])
    }
}
