# Spec: papers (native PDF import, PDF view, highlights, jump to passage)

Status: **built**. Decision 0008. Plan refs: §5 (literature notes), §7 feature 4, §8 phase 2.

## Inputs
- PDF files: ⌘K "Import PDF…", or dropped on the main window.
- Selections in the PDF view (⇧⌘H "Highlight", or "Highlight with Comment…").
- Search hits and Q&A citations in `Papers/text/`, and `granite://pdf?path=&page=&block=` links.

## Outputs
- `Papers/<citekey>.md` (literature note), `Papers/pdf/<citekey>.pdf`, `Papers/text/<citekey>.md` (one `## Page N` per page; OCR for scanned PDFs). Written as the user through `SafeWriter`, then indexed.
- Highlights as `> quote ^p<page>-<id>` blocks with page, link and optional comment, inside the `granite:pdf` managed region of the literature note; everything outside the region is left byte for byte.
- A PDF window per file that opens at a page and marks a highlight or passage (orange) and all the note's highlights (yellow), drawn in memory only.

## Rules
- Duplicate PDFs (same bytes) are refused and point to the existing note; files over 50 MB are refused.
- Citekeys: family name + year + first meaningful title word, ASCII, lowercase, `b`, `c`… on collision; without an author, title word + year.
- Page text: wrapped lines and hyphenation rejoined; short title, byline and heading lines kept apart; leading `#`, `>`, `|`, fences and `[[` escaped so the text can't create headings, quotes or links.
- See-also never proposes links from `Papers/text/` notes; related items show a paper once (the note and its text share a title, and `[[citekey]]` resolves to the note).
- ⌘-click on a URL in the editor: `granite://` goes to granite; `http`, `https`, `zotero`, `mailto` open in their apps; other schemes are refused.

## Files
`Packages/KBPapers` (`Paper.swift`, `LiteratureNote.swift`, `PaperImporter.swift`), `App/Papers/Papers.swift`, `App/Papers/PDFReaderView.swift`, `KBCapture.GraniteURL` (`pdf` action), `Editor/src/editor.ts` (URL ⌘-click); tests `KBPapersTests` (generated text and scanned PDFs), `CaptureTests` (URLs), `features.test.ts`.

## Done when
- [x] Import, duplicate refusal, OCR, citekeys, cleaning, highlight region round trip (KBPapers tests).
- [x] Scratch vault: a PDF imported through the app; the PDF window opens at page 1 and marks the highlight from the note (`--import-pdf`, `--pdf path:page`, `GRANITE_DEBUG_PDF=1`).
- [ ] You import a few real papers; check the text quality, and whether Docling is needed (Phase 3).
