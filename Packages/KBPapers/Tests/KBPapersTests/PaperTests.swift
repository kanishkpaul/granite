import AppKit
import CoreText
import Foundation
import KBCore
import PDFKit
import Testing
@testable import KBPapers

/// Writes a PDF with the given page texts (real text, extractable by PDFKit).
func makePDF(_ pages: [String], title: String? = nil, author: String? = nil, image: Bool = false) -> Data {
    let data = NSMutableData()
    var box = CGRect(x: 0, y: 0, width: 612, height: 792)
    var info: [CFString: Any] = [:]
    if let title { info[kCGPDFContextTitle] = title }
    if let author { info[kCGPDFContextAuthor] = author }
    guard let consumer = CGDataConsumer(data: data as CFMutableData),
          let context = CGContext(consumer: consumer, mediaBox: &box, info as CFDictionary) else { return Data() }
    for text in pages {
        context.beginPDFPage(nil)
        let attributed = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: image ? 28 : 11)])
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let path = CGPath(rect: CGRect(x: 54, y: 54, width: 504, height: 684), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
        if image {
            // Draw the text into a bitmap and place the bitmap: a "scanned" page with no text layer.
            let bitmap = CGContext(data: nil, width: 1224, height: 1584, bitsPerComponent: 8, bytesPerRow: 0,
                                   space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            bitmap?.setFillColor(.white)
            bitmap?.fill(CGRect(x: 0, y: 0, width: 1224, height: 1584))
            bitmap?.scaleBy(x: 2, y: 2)
            if let bitmap { CTFrameDraw(frame, bitmap) }
            if let picture = bitmap?.makeImage() { context.draw(picture, in: box) }
        } else {
            CTFrameDraw(frame, context)
        }
        context.endPDFPage()
    }
    context.closePDF()
    return data as Data
}

@Suite struct PaperTextTests {
    @Test func citekeys() {
        let meta = PaperMetadata(title: "The Attention Is All You Need", authors: ["Ashish Vaswani", "Noam Shazeer"], year: 2017)
        #expect(Citekey.make(for: meta, existing: []) == "vaswani2017attention")
        #expect(Citekey.make(for: meta, existing: ["vaswani2017attention"]) == "vaswani2017attentionb")
        #expect(Citekey.make(for: PaperMetadata(title: "Über Größe", authors: ["Müller, K."], year: 2020), existing: []) == "muller2020uber")
        #expect(Citekey.make(for: PaperMetadata(title: "On the Contextual Retrieval"), existing: []) == "contextualretrieval")
        #expect(Citekey.make(for: PaperMetadata(title: "Contextual Retrieval", year: 2024), existing: []) == "contextual2024")
    }

    @Test func doiYearAndTitle() {
        #expect(PaperText.doi(in: "see https://doi.org/10.1145/3292500.3330701.") == "10.1145/3292500.3330701")
        #expect(PaperText.doi(in: "no identifier") == nil)
        #expect(PaperText.year(in: "Page 1 of 3099, published 2019 in Proc.") == 2019)
        #expect(PaperText.year(in: "values 1850 and 2999") == nil)
        #expect(PaperText.titleGuess(fromFirstPage: "arXiv:2401.0001\n\nDense Retrieval at Scale\nJ. Doe") == "Dense Retrieval at Scale")
    }

    @Test func cleaningRejoinsLinesAndEscapes() {
        let page = """
            Retrieval augmented generation com-
            bines a retriever with a generator and
            works well.
            # not a heading
            Next paragraph ends here.
            """
        let cleaned = PaperText.clean(page)
        #expect(cleaned.hasPrefix("Retrieval augmented generation combines a retriever with a generator and works well."))
        #expect(cleaned.contains("\\# not a heading"))
        let titled = PaperText.clean("A Short Title\nJane Doe\nThis is a long line of body text that wraps onto the next\nline and keeps going for a while longer.")
        #expect(titled.hasPrefix("A Short Title\n\nJane Doe\n\nThis is a long line"))
        #expect(PaperText.page(fromHeadingPath: "Page 12") == 12)
        #expect(PaperText.page(fromHeadingPath: "Intro") == nil)
        #expect(PaperPaths.citekey(of: "Papers/text/x2020y.md") == "x2020y")
        #expect(PaperPaths.citekey(of: "Papers/pdf/x2020y.pdf") == "x2020y")
        #expect(PaperPaths.citekey(of: "Notes/x.md") == nil)
    }
}

@Suite struct LiteratureNoteTests {
    let paths = PaperPaths(citekey: "doe2024dense")

    @Test func renderParsesAsASourceNote() {
        let text = LiteratureNote.render(paths: paths, metadata: PaperMetadata(title: "Dense: Retrieval", authors: ["Jane Doe"],
                                                                               year: 2024, doi: "10.1/x", pageCount: 9),
                                         created: "2026-11-09")
        let note = NoteParser.parse(data: Data(text.utf8), path: paths.note, policy: .builtIn)
        #expect(note.type == .source && note.kind == "paper" && note.title == "doe2024dense")
        #expect(note.frontmatter?["pdf"]?.text == "Papers/pdf/doe2024dense.pdf")
        #expect(note.frontmatter?["title"]?.text == "Dense: Retrieval")
        #expect(note.links.contains { $0.target == "Papers/text/doe2024dense" })
    }

    @Test func highlightsLiveInTheManagedRegionOnly() throws {
        var text = LiteratureNote.render(paths: paths, metadata: PaperMetadata(title: "T"), created: "2026-11-09")
        text = text.replacingOccurrences(of: "## My take\n\n", with: "## My take\nMine, untouched.\n")
        let late = Highlight(page: 5, text: "Later finding with [[brackets]].", comment: "check")
        let early = Highlight(page: 2, text: "Early finding.")
        text = LiteratureNote.upsert(late, in: text, pdfPath: paths.pdf)
        text = LiteratureNote.upsert(early, in: text, pdfPath: paths.pdf)
        #expect(text.contains("## My take\nMine, untouched.\n"))
        let found = LiteratureNote.highlights(in: text)
        #expect(found.map(\.id) == [early.id, late.id])
        #expect(found[1].text == "Later finding with [[brackets]]." && found[1].comment == "check" && found[1].page == 5)
        #expect(text.contains("> Early finding. ^\(early.id)"))
        #expect(text.contains("granite://pdf?path=Papers/pdf/doe2024dense.pdf&page=2&block=\(early.id)"))
        let note = NoteParser.parse(data: Data(text.utf8), path: paths.note, policy: .builtIn)
        #expect(note.blocks.contains { $0.blockID == early.id })

        text = LiteratureNote.remove(id: early.id, in: text, pdfPath: paths.pdf)
        #expect(LiteratureNote.highlights(in: text).map(\.id) == [late.id])
        // A note without the region gets one appended.
        let bare = LiteratureNote.upsert(early, in: "# Hand-written\n", pdfPath: paths.pdf)
        #expect(bare.hasPrefix("# Hand-written\n\n<!-- granite:pdf:begin"))
    }
}

@Suite struct PaperImporterTests {
    func vault() throws -> Vault {
        let root = FileManager.default.temporaryDirectory.appending(path: "granite-papers-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return Vault(root: root)
    }

    @Test func importsTextPDF() async throws {
        let vault = try vault()
        let pdf = vault.root.deletingLastPathComponent().appending(path: "\(UUID().uuidString).pdf")
        try makePDF(["Dense Retrieval at Scale\nJane Doe\n2024\ndoi:10.5555/12345678\nWe study dense retrieval.",
                     "Section two says reranking helps."], title: "Dense Retrieval at Scale", author: "Jane Doe").write(to: pdf)
        let importer = PaperImporter(vault: vault, writer: SafeWriter(vault: vault))
        let result = try await importer.importPDF(at: pdf)
        #expect(result.paths.citekey == "doe2024dense" && !result.ocr)
        #expect(result.metadata.doi == "10.5555/12345678" && result.metadata.pageCount == 2)
        let text = try String(contentsOf: vault.url(for: result.paths.text), encoding: .utf8)
        #expect(text.contains("## Page 2\nSection two says reranking helps."))
        #expect(FileManager.default.fileExists(atPath: vault.url(for: result.paths.pdf).path(percentEncoded: false)))
        await #expect(throws: PaperImportError.duplicate(note: "Papers/doe2024dense.md")) { try await importer.importPDF(at: pdf) }
    }

    @Test func scannedPDFGoesThroughOCR() async throws {
        let vault = try vault()
        let pdf = vault.root.deletingLastPathComponent().appending(path: "\(UUID().uuidString).pdf")
        try makePDF(["Scanned pages need optical character recognition"], image: true).write(to: pdf)
        let result = try await PaperImporter(vault: vault, writer: SafeWriter(vault: vault)).importPDF(at: pdf)
        #expect(result.ocr)
        let text = try String(contentsOf: vault.url(for: result.paths.text), encoding: .utf8)
        #expect(text.contains("text: ocr") && text.lowercased().contains("optical character"))
    }

    @Test func refusesNonPDF() async throws {
        let vault = try vault()
        let file = vault.root.deletingLastPathComponent().appending(path: "\(UUID().uuidString).pdf")
        try Data("not a pdf".utf8).write(to: file)
        await #expect(throws: PaperImportError.self) {
            try await PaperImporter(vault: vault, writer: SafeWriter(vault: vault)).importPDF(at: file)
        }
    }
}
