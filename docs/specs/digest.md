# Spec: lint, nightly digest and the 3 a.m. scheduler

Status: **built**. Plan refs: §7 idea 7, §8 phase 3, §11.

## Inputs
- The index (changed notes since the last digest, links, properties, blocks, vectors) and the model router.

## Outputs
- `AI/Digests/YYYY-MM-DD.md` (`type: digest`, `origin: ai`, `model`, `ai:` label, `covers`), written as AI:
  - **What changed**: changed notes clustered by meaning (cosine ≥ 0.55 between note vectors; by folder without vectors), one sentence per note citing it (`task: digest`; cloud → Sonnet, else MLX or on-device; no model → each note's first line). Every changed note appears.
  - **Open questions you wrote**: sentences ending in "?" and `> [!question]` callouts in your own changed notes (not code, prompts or headings).
  - **New sources touching your claims**: recent `source` passages whose vectors are within 0.75 cosine of a held claim ("reread before trusting it"; NLI checking is a later refinement).
  - **Lint** (`KBIndex.VaultLint`, deterministic): unresolved note links, orphans (links from `AI/` don't count), missing claim/source properties, held claims with `as_of` over a year old, YAML errors, inbox items over 14 days, `origin: ai` outside `AI/`, uncited paragraphs in `AI/Synthesis/`.

## Rules
- Notes labelled `none` never appear. The digest's `ai:` label is the strictest of everything it lists, so MCP can't see private titles through it.
- Digest links are path-style (`[[Notes/X|X]]`), and the inspector hides backlinks from `AI/`.
- **Scheduler**: while granite runs (menu bar), the digest runs at 3 a.m.; a missed night is caught up once, three minutes after launch. After the nightly digest, see-also suggests links. ⌘K "Run digest now" and "Open latest digest".
- Cloud digests use direct calls; the plan's Batch API (50% off) is a later cost optimisation.

## Files
`Packages/KBIndex/Sources/KBIndex/Lint.swift`, `ClaimTouches.swift`, `Packages/KBAI/Sources/KBAI/Digest.swift`, `App/Nightly.swift`; tests `LintTests`, `ClaimTouchTests`, `DigestTests`.

## Done when
- [x] Every lint rule; touches; digest with a model, without one, `none` notes excluded, label raised (tests).
- [x] Scratch vault, on-device model: nine changed notes summarized with citations, lint listed (`--digest`).
- [ ] Gate (phase 3): you open the digest ≥ 4 days a week.
