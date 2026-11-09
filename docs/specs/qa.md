# Spec: grounded Q&A (phase 2, feature 1)

Status: **built**. Plan refs: §7 feature 1, §6.2 retrieval, §6.3 citation verification, principle 4 (evidence scope), principle 5 (Socratic by default).

## Inputs
A question; optionally your own view first (Socratic mode). Evidence comes from your notes and sources only: `AI/` is excluded.

## Pipeline (`KBAI.GroundedQA`)
1. Retrieve: hybrid search with the Qwen3 reranker (notes instruction), top 8.
2. Keep passages scoring at least 10% of the best (and above the abstention threshold): weak ones add noise and would make the label, and so the route, stricter than needed.
3. Abstain ("I have no note on that") if nothing scores above `abstainBelow` (0.005 for now; tune on your re-find set).
4. Route `qa` through `ModelService` under the strictest label of the kept passages: Haiku 5.5 for cloud notes when a key is set, else PCC, else on-device.
5. Answer only from the passages:
   - Claude: passages as citable `document` blocks; each cited text block becomes a sentence; uncited text is marked unsupported.
   - Apple on-device / PCC: guided generation of `[{source, quote, text}]` (source and quote are generated before the sentence; no up-front "answered" flag, which made the model commit to "no" before reading).
6. Verify every sentence the same way, whatever the route: the cited passage must exist and the quote must appear in it after normalization, exactly or with ≥ 90% word overlap. Unverified sentences are struck through and labelled unsupported, never shown as fact.

## App (⌘J, "Ask your notes")
- "Ask my view first" is on by default: you write your view, and the answer weighs it against your notes. "Just tell me" is one click and is logged as a feature event.
- Sentences link to their passage (hover shows the quote); sources list with origin badges; route, label and verification count in the footer.
- On "I have no note on that", you mark it right or wrong (`qa_log.abstention_correct`, the correct-abstention metric).

## Results (real models, 10-note English test vault, on-device route)
5/5 answerable questions answered with 1/1 verified sentences in 1.2–2.5 s; "capital of Mongolia" abstained; Socratic mode correctly said the notes contradict "run hard every day". Finance questions tripped the on-device default guardrail ("may contain sensitive content") until the provider switched to `permissiveContentTransformations`, Apple's setting for transforming the user's own content.

## Done when
- [x] Tests: verifier (exact, normalized, 90% overlap, unknown source), abstention without a model call, per-sentence verification, empty answer abstains, Claude citations to sentences, private labels keep answers off the cloud, weak passages dropped before labelling.
- [x] App Ask window, Q&A log, abstention verdicts.
- [ ] Gates (you): ≥ 1 Q&A per day for 2 weeks; citation verification ≥ 95% over your real questions.
