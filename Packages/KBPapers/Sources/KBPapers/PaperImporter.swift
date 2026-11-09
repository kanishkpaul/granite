import CryptoKit
import Foundation
import KBCore
import PDFKit
import Vision

public enum PaperImportError: Error, Equatable, CustomStringConvertible {
    case unreadable(String)
    case tooLarge(Int)
    case duplicate(note: String)

    public var description: String {
        switch self {
        case .unreadable(let name): "\(name) is not a readable PDF"
        case .tooLarge(let megabytes): "the PDF is \(megabytes) MB; granite keeps attachments under \(PaperImporter.maxMegabytes) MB"
        case .duplicate(let note): "this PDF is already in the vault: \(note)"
        }
    }
}

public struct PaperImportResult: Sendable, Equatable {
    public let paths: PaperPaths
    public let metadata: PaperMetadata
    /// The text came from OCR (a scanned PDF).
    public let ocr: Bool
    public var written: [String] { [paths.pdf, paths.text, paths.note] }
}

/// Native paper import (decision 0008, instead of Zotero for now): drop a PDF → the PDF copied to
/// `Papers/pdf/`, its text to `Papers/text/` (OCR when the PDF has none), and a literature note.
public actor PaperImporter {
    public static let maxMegabytes = 50
    let vault: Vault
    let writer: SafeWriter

    public init(vault: Vault, writer: SafeWriter) {
        self.vault = vault
        self.writer = writer
    }

    public func importPDF(at url: URL, now: Date = Date()) async throws -> PaperImportResult {
        let data = try Data(contentsOf: url)
        guard data.count <= Self.maxMegabytes * 1_048_576 else { throw PaperImportError.tooLarge(data.count / 1_048_576) }
        if let existing = duplicate(of: data) { throw PaperImportError.duplicate(note: PaperPaths(citekey: existing).note) }
        guard let document = PDFDocument(data: data), document.pageCount > 0 else {
            throw PaperImportError.unreadable(url.lastPathComponent)
        }

        var pages = (0..<document.pageCount).map { document.page(at: $0)?.string ?? "" }
        var ocr = false
        if pages.joined().filter({ !$0.isWhitespace }).count < 40 * max(1, min(pages.count, 3)) {
            let recognized = await Self.recognizeText(document)
            if recognized.joined().count > pages.joined().count {
                pages = recognized
                ocr = true
            }
        }
        var metadata = Self.metadata(document: document, pages: pages, fallbackTitle: url.deletingPathExtension().lastPathComponent,
                                     now: now)
        metadata.pageCount = document.pageCount
        let paths = PaperPaths(citekey: Citekey.make(for: metadata, existing: existingCitekeys()))

        try await writer.write(data, to: paths.pdf, as: .user)
        try await writer.write(PaperText.textNote(paths: paths, title: metadata.title, pages: pages, ocr: ocr), to: paths.text, as: .user)
        try await writer.write(LiteratureNote.render(paths: paths, metadata: metadata, created: Self.day(now)), to: paths.note, as: .user)
        return PaperImportResult(paths: paths, metadata: metadata, ocr: ocr)
    }

    static func metadata(document: PDFDocument, pages: [String], fallbackTitle: String, now: Date) -> PaperMetadata {
        let attributes = document.documentAttributes ?? [:]
        let first = pages.first ?? ""
        let firstTwo = pages.prefix(2).joined(separator: "\n")
        var title = (attributes[PDFDocumentAttribute.titleAttribute] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // Many PDFs carry the file name or a tool's placeholder as their title.
        if title.count < 6 || title.lowercased().hasSuffix(".pdf") || title.lowercased().hasPrefix("microsoft word") {
            title = PaperText.titleGuess(fromFirstPage: first) ?? fallbackTitle
        }
        let authorText = (attributes[PDFDocumentAttribute.authorAttribute] as? String) ?? ""
        let authors = authorText.components(separatedBy: CharacterSet(charactersIn: ";,&"))
            .flatMap { $0.components(separatedBy: " and ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count > 1 }
        let created = attributes[PDFDocumentAttribute.creationDateAttribute] as? Date
        let year = PaperText.year(in: first, now: now) ?? created.map { Calendar(identifier: .gregorian).component(.year, from: $0) }
        return PaperMetadata(title: title, authors: authors, year: year, doi: PaperText.doi(in: firstTwo), pageCount: document.pageCount)
    }

    func existingCitekeys() -> Set<String> {
        let folder = vault.url(for: "Papers")
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []
        let pdfs = (try? FileManager.default.contentsOfDirectory(atPath: folder.appending(path: "pdf").path(percentEncoded: false))) ?? []
        return Set(names.filter { $0.hasSuffix(".md") }.map { String($0.dropLast(3)) } + pdfs.map { String($0.dropLast(4)) })
    }

    /// The citekey of an identical PDF already in `Papers/pdf/`.
    func duplicate(of data: Data) -> String? {
        let folder = vault.url(for: "Papers/pdf")
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)) else { return nil }
        let hash = SHA256.hash(data: data)
        for name in names where name.hasSuffix(".pdf") {
            let url = folder.appending(path: name)
            guard let size = try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))[.size] as? Int,
                  size == data.count, let other = try? Data(contentsOf: url), SHA256.hash(data: other) == hash else { continue }
            return String(name.dropLast(4))
        }
        return nil
    }

    /// Vision OCR, page by page, for scanned PDFs.
    static func recognizeText(_ document: PDFDocument) async -> [String] {
        var pages: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else {
                pages.append("")
                continue
            }
            let bounds = page.bounds(for: .mediaBox)
            let scale = 2.0
            let image = page.thumbnail(of: CGSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox)
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                pages.append("")
                continue
            }
            var request = RecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let observations = (try? await request.perform(on: cgImage)) ?? []
            pages.append(observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n"))
        }
        return pages
    }

    static func day(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
