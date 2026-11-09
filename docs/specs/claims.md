# Spec: claim and belief ledger

Status: **built**. Plan refs: §4.4–4.5 (claim type and frontmatter), §7 idea 5, §8 phase 3, §11 "belief motion".

## Inputs
- The selection in the editor, or the paragraph at the cursor (⌥⌘P "Promote to Claim…", ⌘K).
- An open claim (inspector: status menu, "Supersede…"; Note menu "Supersede Claim…").

## Outputs
- **Promote**: `Notes/<first sentence>.md` with `type: claim`, `origin: human`, `status: held`, `confidence`, `created`/`as_of`, and `source: ["[[Note#^c-xxxxxx]]"]` citing the paragraph it came from. The source paragraph gets a `^c-…` block id if it has none (the only change to it).
- **Supersede**: a new claim with `supersedes: ["[[Old claim]]"]`; the old claim's `status` becomes `superseded`. Its body is never touched.
- **Status**: held / revised / retired from the inspector; `as_of` moves to today except on retirement.
- **Ledger**: sidebar "Claims" (count of held) lists every claim by status with confidence, `as_of` and tags, filterable; the inspector shows the supersede chain (oldest first) for the open claim.

## Rules
- Only claims you promote are truth (principle 1); nothing here is written by a model.
- The link to a source or old claim uses the note title when it is unique, else the path.
- History follows `supersedes` links both ways and keeps chain order, whatever the dates or names.
- Headings, code, math and tables can't be cited; promote from a paragraph, list item, quote or callout.

## Files
`Packages/KBCore/Sources/KBCore/Claim.swift`, `Packages/KBIndex/Sources/KBIndex/ClaimService.swift`, `App/Claims/`; tests `ClaimTests`, `ClaimServiceTests`.

## Done when
- [x] Render, titles, block ids; promote, supersede chain (both directions, same-day), status and `as_of` (tests).
- [x] Through the app on a scratch vault: promote a line, supersede it, chain reported in order (`--promote-line N`).
- [ ] Gate (phase 3): ≥ 30 held claims, ≥ 3 superseded (you).
