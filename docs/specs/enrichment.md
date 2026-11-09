# Spec: enrichment and Docling

Status: **built**. Plan refs: §5 steps 4 and 6, §8 phase 3 ("enrichment (Crossref/OpenAlex/S2); Docling for study papers").

## Enrichment (on request)
- **Input**: a literature note (or its PDF or full text) with a `doi`, else a `title`. Inspector → Paper → "Look Up", or ⌘K.
- **Lookups**: Crossref `/works/{doi}`, OpenAlex `/works/https://doi.org/{doi}` (or `?search=` by title), Semantic Scholar `/graph/v1/paper/DOI:{doi}`. One request each, run together; one failing doesn't stop the others. User-Agent `granite/0.1`; no account, key or email address is sent. Only the DOI or title leaves the Mac.
- **Merge**: Crossref for title, authors, year, venue; OpenAlex for its id, references and abstract; Semantic Scholar for the TL;DR; the highest citation count.
- **Output**: frontmatter `title`, `authors`, `year`, `doi`, `venue`, `openalex`, `cited_by`, `enriched`; and a `granite:enrich` managed region ("About this paper": TL;DR, abstract, venue, counts, DOI and OpenAlex links) placed before "My take". Refreshing replaces the region only.
- New frontmatter keys are appended after yours (an `id` goes first); a block list is replaced whole (`FrontmatterEditor.setRaw`).

## Docling (for papers you study)
- Only when the `docling` CLI is installed (PATH, `~/.local/bin`, Homebrew); otherwise the button explains how to install it.
- Runs `docling --to md --output <tmp> <pdf>` as a subprocess (10-minute limit), caches the Markdown in Application Support (`docling/<citekey>.md`, rebuildable, outside the vault), and rewrites `Papers/text/<citekey>.md` from it (`text: docling`, the paper's headings one level down). The literature note's `status` becomes `studied`.
- Docling text has no page sections, so jumping from a hit searches the whole PDF for the passage.

## Files
`Packages/KBPapers/Sources/KBPapers/Enrichment.swift`, `Docling.swift`, `App/Papers/Papers.swift`; tests `EnrichmentTests` (canned API answers, merge, no email, writer, block lists), `DoclingTests` (stand-in CLI, cache, failure, note rewrite).

## Done when
- [x] Tests above.
- [x] Live: one DOI looked up through the app (title, eight authors, year, venue, abstract, TL;DR, citations).
- [ ] Docling on a real paper once you install it (you).
