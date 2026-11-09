# Spec: contradictions, claim touches and the belief diff

Status: **built**. Plan refs: §5 step 6 (touch check with NLI), §7 (contradiction detection, new-source alerts, quarterly belief diff), §11 (belief motion, quarterly cadence).

## NLI check (`KBAI.NLIChecker`)
Two statements → `supports | contradicts | unrelated` and one short reason (task `nli`: cloud → Sonnet, otherwise MLX or on-device). A cue to reread, never a verdict.

## In the nightly digest
- **New sources touching your claims** (from `ClaimTouches`, cosine ≥ 0.75): each match is NLI-checked; unrelated ones drop out; the rest show the relation and reason.
- **Claims that may contradict each other**: held-claim pairs with cosine ≥ 0.7 that you haven't linked (`contradicts`, `supports`, `supersedes`), NLI-checked; only `contradicts` verdicts are listed (without a model: listed as "close; no model checked them"). At most 10 pairs a night. The suggested fix is yours: supersede one, or link both with `contradicts`.
- When either section has entries, a notification says so (permission asked the first time).

## Quarterly belief diff (`KBAI.BeliefDiff`)
- `AI/Synthesis/Belief diff YYYY-Qn.md`: counts (new, revised, superseded, retired, held throughout), lists with dates and what each new claim replaced, and with a model a three-to-six-sentence narrative citing the claims (task `beliefDiff`: cloud → Opus or Sonnet, otherwise MLX or on-device).
- ⌘K "Belief diff for this quarter" anytime; written automatically on the first night of a new quarter for the quarter just ended.
- `none` claims never appear; the note carries the strictest label it read.

## Files
`Packages/KBAI/Sources/KBAI/Beliefs.swift`, `Digest.swift`, `Packages/KBIndex/Sources/KBIndex/ClaimTouches.swift` (`ClaimPairs`), `App/Nightly.swift`; tests `BeliefTests`, `ClaimPairTests`, `DigestTests`.

## Done when
- [x] Tests above; belief diff written through the app with an on-device narrative.
- [ ] Quarterly: read the diff (you, §11 cadence).
