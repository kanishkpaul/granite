# Spec: trails

Status: **built**. Plan refs: §4.4 (`kind: trail`), §7 idea 10, §8 phase 4.

## Format
A note with `kind: trail` (in `Notes/Trails/` by default): an ordered list of links, each with one sentence of yours.
```
---
type: note
kind: trail
status: endorsed      # candidate until you name it and write the sentences
---
# From BM25 to rerankers
1. [[BM25]] — where keyword search starts.
2. [[Hybrid retrieval]] — adding vectors.
```
Steps are numbered or bulleted lines that start with a wikilink; the text after `—`, `–`, `:` or `-` is the sentence. A `(placeholder)` counts as no sentence.

## Candidates (proposals, feature `trails`)
- **From your links**: ⌘K "Suggest trails from your links": chains of three to seven notes changed in the last month, each linking to the next (no Daily, Inbox, AI or `none` notes; a note in at most one candidate; longest chains first).
- **From a question**: "Make a Trail from These Sources" under an answer citing two or more notes, in the order the answer used them.
- Each is a `trail` proposal creating `Notes/Trails/<title>.md` with `status: candidate` and placeholder sentences. A trail only counts once you've named it, written the sentences and set `status: endorsed`.

## Walking
The inspector of a trail lists its steps and offers "Walk This Trail": each step opens in the editor while the inspector shows "Step i of n", your sentence, Back, Next and End.

## Files
`Packages/KBCore/Sources/KBCore/Trail.swift`, `Packages/KBIndex/Sources/KBIndex/TrailSuggester.swift`, `App/Trails/Trails.swift`; tests `TrailTests`, `TrailSuggesterTests`.

## Done when
- [x] Parsing, candidates, chain finding (tests); a chain proposed on the scratch vault, not proposed twice.
- [ ] You endorse a trail you'd walk again (you).
