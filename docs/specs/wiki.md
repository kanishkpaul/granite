# Spec: scoped LLM wiki

Status: **built**. Plan refs: §4.3 (`AI/Wiki/<domain>/`), §7 phase 4 ("a scoped LLM wiki for one reference domain you need to query, never for your own thinking").

## Inputs
- A domain (⌘K "Build a wiki for a domain…"): a name, source folders (default Papers, Clippings, References) and optional tags. Saved in `.granite/wiki.json`; building the same name again rebuilds it.
- Only `source` and `clipping` notes in those folders (not full-text copies, not `none` notes). Your notes, claims and daily notes are never read.

## Outputs
- `AI/Wiki/<domain>/index.md` (topics, sources, topics the sources couldn't support) and one page per topic (`type: synthesis`, `kind: wiki`, `origin: ai`, `model`, `ai:` label), with "See also" links between pages.

## How
1. Topics: a model plans five to ten from the sources' titles and headings (task `extraction`); without a model, the headings most sources share.
2. Each page is a grounded answer (`GroundedQA`) to "what do the sources say about <topic>", retrieving by the topic within the domain's source notes only. Every sentence carries a quote checked against its passage; unverified sentences are dropped, and a topic with none is skipped.
3. Pages written by an on-device or MLX model carry a warning callout (the plan reserves synthesis for large models; a small model's pages need a warning).
4. Rebuilding overwrites the domain's pages: `AI/` is regenerable.

## Files
`Packages/KBAI/Sources/KBAI/Wiki.swift`, `App/Trails/Wiki.swift`; test `WikiTests` (sources only, verified sentences only, skipped topics, index and links).

## Done when
- [x] Test above; a wiki built through the app from the scratch sources (on-device, warning shown).
- [ ] A domain you actually query (you).
