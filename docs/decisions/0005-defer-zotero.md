# 0005: Defer the Zotero integration

Date: 2026-11-09 · Status: **accepted** · Plan: §5, §7 feature 4, §8 spike C, phase 2

## Context
The plan makes Zotero the home for papers (capture, PDFs, annotation, citations) and has granite render literature notes from Zotero highlights. Spike C was to prove the Zotero 10 local API. The owner hasn't used Zotero in practice, and it isn't installed on this Mac.

## Decision
1. **Spike C leaves Phase 0.** Phase 0 is done when spikes A, B and D pass (or have fallbacks).
2. **Phase 2 drops "Zotero sync + literature notes"** until there is a real reading workflow to integrate with. `KBZotero` is not created.
3. **Papers still fit the vault.** A paper can be a `source` note in `Papers/` written by hand (citekey, DOI, your take, quoted passages as `^block`s), and claims can cite those blocks today. The parser, index, search and MCP already handle this.
4. **Revisit when** you've read 10+ papers in one tool, or Phase 2 starts. The choice then: adopt Zotero and run spike C, or build a small native path (drop a PDF → PDFKit text → `Papers/` note with highlights as blocks).

## Consequences
- Plan features that assumed Zotero (managed annotation regions, `zotero://` deep links, write-back tags, enrichment through Zotero) wait.
- Literature-graph expansion (feature 9) can still use DOIs from hand-written source notes.
