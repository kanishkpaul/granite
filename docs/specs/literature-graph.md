# Spec: literature-graph expansion

Status: **built**. Plan refs: §7 idea 9, §8 phase 4.

## Inputs
- A paper's literature note with `openalex` or `doi` (after "Look Up", see `enrichment.md`). Inspector → Paper → "Expand Literature Graph", or ⌘K.

## Outputs
- `AI/Reading/<citekey> graph.md` (`type: synthesis`, `kind: reading-list`, `origin: ai`, `model: none`): "It cites" and "Cited by" lists (up to 15 each) with title, year, venue, citation count, DOI link, and the closest note of yours with its similarity.

## Rules
- Two OpenAlex requests per seed (one batch for up to 50 references, one for the 25 most-cited citing works). Only the DOI or OpenAlex id is sent.
- Papers whose DOI is already in your vault are left out.
- Ranking: each candidate's title and abstract is embedded locally and compared with your chunks (the seed's own note and text and `AI/` excluded); without vectors, a keyword search over your notes. Ties go to the more cited paper.
- Candidates, not reading: nothing is imported. Adding one means getting its PDF and importing it.

## Files
`Packages/KBPapers/Sources/KBPapers/LiteratureGraph.swift`, `ScholarlyClient.openAlexWorks/openAlexCitedBy`, `KBIndex.IndexDatabase.knownDOIs/path(ofChunk:)`, `App/Papers/Papers.swift`; test `LiteratureGraphTests` (mocked OpenAlex: ranking, known DOIs skipped, rendering).

## Done when
- [x] Test above; live on a known paper: 54 candidates ranked against the scratch vault.
