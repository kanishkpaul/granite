# Spec: inline related items

Status: **built**. Plan refs: §7 idea 2, §8 phase 2 ("inline related items").

## Inputs
- The paragraph at the cursor, sent by the editor after a 1.2 s pause in typing or moving (bridge v3 `context {id, text, line}`), when it has at least 8 words and is not frontmatter, a heading or code.

## Outputs
- `related {id, items}`: up to three ghost links shown at the end of that paragraph. Each item: `target`, `title`, `reason` (`mention` | `similar`), `mention` (the words that name the note), `detail` (tooltip).
- Clicking a ghost link inserts a real link: a mention becomes `[[Title|words]]` in place (or `[[Title]]` when the words are the title); a similar note is appended as `(see [[Title]])`. × hides it for that note for the session. Both send `relatedDecision {target, accepted|dismissed}`.
- `state.sqlite` `feature_events` for feature `related`: `shown` once per note and target per session, then `accepted` or `rejected`.

## Rules
- Candidates come from `KBIndex.RelatedFinder.forText` (see `proposals.md`): unlinked title/alias mentions first, then passages with cosine ≥ 0.6 to the paragraph's embedding (one EmbeddingGemma document embedding, only when semantic search is on). Excludes the note, notes it already links, `AI/`, proposals, digests, syntheses and notes labelled `none`.
- Stale answers (an older `id`) are dropped; the ghost links follow edits and disappear when the cursor leaves the paragraph.
- Paused automatically below 10% acceptance once 20 have been shown in 28 days (`FeatureGuard`, shared with the proposal queue). Settings → AI → "Show related notes while writing" turns it off.

## Files
`Editor/src/related.ts`, `Editor/src/editor.ts`, `Editor/src/bridge.ts`, `App/Bridges/EditorBridge.swift`, `App/Related.swift`; tests `Editor/test/related.test.ts`, bridge fixtures (both sides).

## Done when
- [x] Paragraph detection, accept edits, anchoring, stale answers and decisions tested in Vitest; bridge v3 round-trips in Swift and TypeScript.
- [x] Scratch vault: three ghost links under a paragraph (`--snapshot … --open <note> --related-line N`).
- [ ] Gate: you accept some; the threshold is tuned from `feature_events` after a few weeks.
