# 0008: Native paper import instead of Zotero, for now

Date: 2026-11-09 · Status: **accepted** · Plan: §5, §7 feature 4, phase 2 "PDFKit jump to cited passage" · Supersedes part of 0005 (point 4)

## Context
Decision 0005 deferred Zotero: you don't use it, and it isn't installed. It left a choice for Phase 2: adopt Zotero and run spike C, or build "a small native path (drop a PDF → PDFKit text → `Papers/` note with highlights as blocks)". Phase 2 asks for papers in search and Q&A, highlights as citable blocks, and a PDF view that jumps to the cited passage.

## Decision
Build the native path (`Packages/KBPapers`, `App/Papers/`):

1. **Three files per paper**, keyed by a citekey (`doe2024dense`; `contextual2024` without an author):
   - `Papers/<citekey>.md`, the literature note: `type: source`, `kind: paper`, title, authors, year, DOI, `pdf:`; "My take" is yours; a managed region between `granite:pdf` markers holds highlights.
   - `Papers/pdf/<citekey>.pdf`, the PDF itself, in the vault (file over app; under 50 MB, so git stays usable). It is never modified.
   - `Papers/text/<citekey>.md`, the extracted text with one `## Page N` section per page (`kind: paper-text`). Search, Q&A and MCP read it like any note; its heading gives the page for the jump. Scanned PDFs go through Vision OCR (`text: ocr`).
2. **Highlights** are made in the PDF view (⇧⌘H, optionally with a comment) and stored as quote blocks `> text ^p3-ab12cd` with a `granite://pdf?path=…&page=…&block=…` link. They are drawn on the PDF from the note each time it opens; the PDF file keeps no annotations.
3. **Jump to the cited passage**: search hits and Q&A citations in a paper's full text open the PDF at that page with the passage marked; `granite://pdf` links (⌘-click in the editor, or from any app) do the same.
4. Metadata comes from the PDF's attributes and first page (title, authors, year, DOI). Enrichment from Crossref/OpenAlex is Phase 3 and on request.

## Consequences
- Zotero can still be added later: literature notes have the same shape as the plan's §5 notes, and a `KBZotero` sync would write `zotero_key` and its own managed region.
- PDFs in the vault make the git repository larger; the 50 MB cap and one PDF per paper keep it bounded.
- The extracted text is only as good as PDFKit's (or OCR's) reading order; Docling for "study" papers stays a Phase 3 option.
