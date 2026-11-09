import KBCore
import KBPapers
import PDFKit
import SwiftUI

/// The PDF view (one window per PDF): read, highlight a selection into the literature note
/// (⌘⇧H), and jump to cited passages. The PDF file itself is never modified: highlights are drawn
/// from the note each time.
struct PDFReaderView: View {
    @Environment(VaultStore.self) private var store
    let path: String
    @State private var reader = PDFReader()
    @State private var commenting = false
    @State private var comment = ""

    var body: some View {
        PDFKitView(reader: reader)
            .overlay {
                if reader.document == nil {
                    ContentUnavailableView("PDF not found", systemImage: "doc.richtext", description: Text(path))
                }
            }
            .navigationTitle(store.literatureNotePath(forPDF: path).map { NoteParser.title(for: $0) } ?? path)
            .toolbar {
                ToolbarItemGroup {
                    Button("Highlight", systemImage: "highlighter") { Task { await highlight(comment: nil) } }
                        .keyboardShortcut("h", modifiers: [.command, .shift])
                        .help("Save the selection to the literature note (⇧⌘H)")
                        .disabled(!reader.hasSelection)
                    Button("Highlight with Comment…", systemImage: "text.bubble") { comment = ""; commenting = true }
                        .disabled(!reader.hasSelection)
                    if let note = store.literatureNotePath(forPDF: path) {
                        Button("Open Note", systemImage: "doc.text") {
                            AppModel.shared.showMainWindow()
                            store.openNote(note)
                        }
                    }
                }
            }
            .alert("Comment", isPresented: $commenting) {
                TextField("Why it matters", text: $comment)
                Button("Highlight") { Task { await highlight(comment: comment) } }
                Button("Cancel", role: .cancel) {}
            }
            .task(id: path) {
                guard let vault = store.vault else { return }
                reader.load(url: vault.url(for: path))
                reader.draw(store.highlights(forPDF: path))
                if let navigation = store.pdfNavigation[path] { reader.go(navigation) }
            }
            .onChange(of: store.pdfNavigation[path]) { _, navigation in
                if let navigation { reader.go(navigation) }
            }
    }

    private func highlight(comment: String?) async {
        guard let selection = reader.selectionForHighlight() else { return }
        let highlight = Highlight(page: selection.page, text: selection.text, comment: comment)
        await store.addHighlight(highlight, toPDF: path)
        reader.draw(store.highlights(forPDF: path), focus: highlight.id)
    }
}

@MainActor
@Observable
final class PDFReader {
    private(set) var document: PDFDocument?
    var hasSelection = false
    @ObservationIgnored weak var view: PDFView?
    @ObservationIgnored private var drawn: [(PDFPage, PDFAnnotation)] = []
    @ObservationIgnored private var highlightsByID: [String: Highlight] = [:]
    static let marker = "granite"

    func load(url: URL) {
        document = PDFDocument(url: url)
        view?.document = document
    }

    /// The current selection as one line of text and its first page (1-based).
    func selectionForHighlight() -> (page: Int, text: String)? {
        guard let selection = view?.currentSelection, let page = selection.pages.first, let document,
              let text = selection.string?.split(whereSeparator: \.isWhitespace).joined(separator: " "),
              text.count >= 3 else { return nil }
        return (document.index(for: page) + 1, text)
    }

    /// Redraws granite's highlight marks (memory only) for the note's highlights.
    func draw(_ highlights: [Highlight], focus: String? = nil) {
        for (page, annotation) in drawn { page.removeAnnotation(annotation) }
        drawn = []
        highlightsByID = Dictionary(highlights.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for highlight in highlights {
            guard let selection = find(highlight.text, onPage: highlight.page) else { continue }
            mark(selection, color: highlight.id == focus ? .systemOrange : .systemYellow)
        }
    }

    func go(_ navigation: PDFNavigation) {
        guard let document, let page = document.page(at: max(0, min(navigation.page - 1, document.pageCount - 1))) else { return }
        view?.go(to: page)
        var target: PDFSelection?
        if let block = navigation.block, let highlight = highlightsByID[block] {
            target = find(highlight.text, onPage: highlight.page)
        } else if let text = navigation.find {
            target = find(text, onPage: navigation.page)
        }
        if let target {
            mark(target, color: .systemOrange)
            view?.go(to: target)
            view?.setCurrentSelection(target, animate: true)
        }
    }

    /// The passage on a page: the whole text if PDFKit finds it, else its first eight words.
    func find(_ text: String, onPage number: Int) -> PDFSelection? {
        guard let document, let page = document.page(at: number - 1) else { return nil }
        let words = text.split(whereSeparator: \.isWhitespace)
        for candidate in [text, words.prefix(8).joined(separator: " "), words.prefix(4).joined(separator: " ")]
        where candidate.count >= 3 {
            if let match = document.findString(candidate, withOptions: [.caseInsensitive]).first(where: { $0.pages.contains(page) }) {
                return match
            }
        }
        return nil
    }

    private func mark(_ selection: PDFSelection, color: NSColor) {
        if ProcessInfo.processInfo.environment["GRANITE_DEBUG_PDF"] != nil {
            NSLog("granite pdf: mark %d line(s): %@", selection.selectionsByLine().count, selection.string ?? "")
        }
        for line in selection.selectionsByLine() {
            guard let page = line.pages.first else { continue }
            let annotation = PDFAnnotation(bounds: line.bounds(for: page), forType: .highlight, withProperties: nil)
            annotation.color = color.withAlphaComponent(0.45)
            annotation.userName = Self.marker
            page.addAnnotation(annotation)
            drawn.append((page, annotation))
        }
    }
}

struct PDFKitView: NSViewRepresentable {
    let reader: PDFReader

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.document = reader.document
        reader.view = view
        context.coordinator.observe(view)
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if view.document !== reader.document { view.document = reader.document }
    }

    func makeCoordinator() -> Coordinator { Coordinator(reader: reader) }

    @MainActor
    final class Coordinator {
        let reader: PDFReader
        private var task: Task<Void, Never>?

        init(reader: PDFReader) { self.reader = reader }

        /// Tracks whether there is a selection, for the toolbar buttons.
        func observe(_ view: PDFView) {
            task = Task { [weak view, reader] in
                for await _ in NotificationCenter.default.notifications(named: .PDFViewSelectionChanged, object: view) {
                    reader.hasSelection = !(view?.currentSelection?.string ?? "").isEmpty
                }
            }
        }

        deinit { task?.cancel() }
    }
}
