# Spec: spaced retrieval prompts (FSRS)

Status: **built**. Plan refs: §4.6 (reviews.jsonl, rebuilt schedule), §7 idea 6, §8 phase 3, §11 "retention".

## Inputs
- Prompts you write in any note (outside `AI/`) as callouts:
  ```
  > [!prompt] What beats embedding choice?
  > Hybrid search plus a reranker. ^p-k7h2qx
  ```
- "Make prompts from this note" (⌘K, Note menu): the model drafts 3–5 prompts from the open note.
- Grades in the review sheet: Again, Hard, Good, Easy (keys 1–4; space reveals).

## Outputs
- `.granite/reviews.jsonl` in the vault: one line per review `{"ts", "prompt", "grade", "seconds"}`. The schedule is never stored: it is rebuilt by replaying this file through FSRS, so history stays in text and in git.
- Drafted prompts are proposals (`kind: prompt`, feature `make-prompts`); accepting appends the callout to the note.
- A prompt without a block id gets `^p-…` on its first review (its identity: the note's `id`, or its path, plus the block id).

## Rules
- **FSRS-5** with the published default parameters, target retention 90%; a lapse comes back in 10 minutes and again at the end of the session; same-day reviews use the short-term formula.
- **Queue**: due prompts, most overdue first, then new ones up to 10 a day (first reviews made today count).
- **Only prompts on notes you choose** (Matuschak): nothing is drafted unless you ask for that note, and drafts are proposals you rewrite or reject.
- `promptDraft` routing: Haiku for `cloud` notes, else on-device, MLX or PCC.
- The sidebar "Review" shows the due count; ⌃⌘R opens the review.

## Files
`Packages/KBReview` (`FSRS.swift`, `Prompts.swift`, `ReviewQueue.swift`), `Packages/KBAI/Sources/KBAI/PromptDrafter.swift`, `App/Review/`; tests `KBReviewTests` (FSRS defaults, growth and lapses, parsing, log replay, queue, id assignment, daily allowance), `PromptDrafterTests`.

## Done when
- [x] Tests above.
- [x] Scratch vault, on-device model: three prompts drafted as proposals; one hand-written prompt shows as due.
- [ ] Gate (phase 3): daily reviews with ≥ 85% recall (you).
