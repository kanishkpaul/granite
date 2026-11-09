# Spec: metrics dashboard

Status: **built**. Plan refs: §7 idea 12, §11.

## Inputs
- `index.sqlite` (notes, claims, outputs, sources, weekly notes), `state.sqlite` (search events, Q&A log, feature events, audit), git (`git log --numstat` over the last 30 days), `KBReview` stats and the inbox.

## Outputs
- ⌘K "Metrics dashboard" / Note menu "Metrics…": a table of every §11 metric with its value, the healthy signal and a mark (✓, watch, alarm, unknown).
- `AI/Metrics/YYYY-Www.md` (frozen nightly after the digest, or "Save to AI/Metrics"): the same table as Markdown, plus the numbers in `state.sqlite` `metrics(week, key, value)` for trends. No model involved.

## Metrics
| Key | Measure | Healthy |
|---|---|---|
| `own_notes_30d` | your notes, claims, decisions changed in 30 days; new claims | ≥ 8 claims a month early on |
| `inflow_human_share` | lines added in git by origin (AI/ counts as ai) | your share ≥ 25% of non-AI; alarm < 10% |
| `output_per_input` | `kind: output` notes ÷ sources, last quarter | nonzero |
| `refind_success` | searches whose top-5 result was opened within 30 s; median time | time-to-refind < 1 min |
| `correct_abstention` | "no note" answers you marked correct | ≥ 80% |
| `citation_pass_rate` | verified ÷ answer sentences | ≥ 95% |
| `acceptance_<feature>` | accepted + edited ÷ shown, 4 weeks; paused flag | pauses below 10% |
| `egress_cloud_calls` | cloud calls, notes and dollars this week; alarm if any non-cloud label reached a cloud route | no local note on a cloud route |
| `weekly_reviews_4w` | weekly notes in 4 weeks | 4 in a row |
| `retention` | FSRS recall on the last 7 days of reviews | 85–90% |
| `belief_motion` | claims superseded or revised this quarter | > 0 |
| `inbox_median_days` | median inbox age | < 14 days |

## Files
`Packages/KBIndex/Sources/KBIndex/Metrics.swift`, `Packages/KBGit` (`linesAdded`), `App/Review/Metrics.swift`; tests `MetricsTests`, `GitServiceTests.linesAddedPerMarkdownFile`.

## Done when
- [x] Each metric from seeded data, the egress alarm, the frozen file and stored numbers (tests).
- [x] Scratch vault: computed and frozen through the app (`--metrics`).
- [ ] Monthly look at inflow and own writing (you, §11 cadence).
