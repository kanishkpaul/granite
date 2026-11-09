# Spec: proposal queue v1 and see-also link proposals

Status: **built**. Plan refs: §6.4 (proposal format, queue), §7 idea 2 (related items), §8 phase 2 (link proposals), principle 3 (AI writes only to `AI/`).

## Inputs
- `Proposal` values from any AI feature: kind (`link | edit | claim | merge | trail | prompt | tag | rule`), target (`[[Note]]`, or a new note's path for `claim`/`trail`/`merge`), the change as a diff (`-` lines removed, `+` lines added), rationale, citations, model, feature and taint label.
- Your decision: accept, edit then accept, or reject.

## Outputs
- One Markdown file per proposal in `AI/Proposals/` (`2026-11-09 1432 link Hybrid retrieval.md`), in the plan's §6.4 format, written as the AI role (`SafeWriter` refuses AI writes elsewhere).
- On accept: the change applied to the target as the user (you decided). On any decision: the proposal's `status` (`accepted | edited | rejected`) and `decided` date in its frontmatter; an edited proposal keeps its edited diff below the original; one line appended to `AI/log.md`; a `feature_events` row in `state.sqlite`.

## Rules
- **Apply** (`KBCore.ProposalApplier`, pure): `link` adds lines at the end of `## Related` (created at the end of the note if missing); `tag` adds to the frontmatter `tags` list, changing as few lines as possible; `edit` replaces the exact run of `-` lines (trailing whitespace ignored) and fails with a conflict if you changed them since; `prompt`/`rule` and other kinds without `-` lines append; `claim`/`trail`/`merge` with no `-` lines create the target file and refuse if it exists. A conflict changes nothing and leaves the proposal open.
- **Cap**: at most 25 open proposals; creating more throws `queueFull`, and jobs stop.
- **Duplicates**: a change already open or rejected for the same target is never proposed again.
- **Auto-pause**: a feature with at least 20 proposals shown in 28 days and under 10% accepted or edited is paused; its jobs stop until the rate recovers.
- **See-also** (`KBIndex.SeeAlsoJob`): for notes changed in the last week (not `AI/`, not `Inbox/`, not labelled `none`), proposes at most one link per note per run to the best related note (`RelatedFinder`): unlinked title or alias mentions first, then passages whose vectors are close (cosine ≥ 0.6, mean of the note's chunk vectors; no model call). The reason is one sentence from the `linkReason` task (on-device first, labels respected, background budget rules), or a plain description when no model answers. Runs a minute after a vault opens, at most every 20 hours, or from ⌘K "Suggest links".
- **Related finder**: excludes the note, notes it already links, `AI/`, proposals, digests and syntheses. One-word titles count as mentions only when capitalized mid-sentence. The same finder will drive inline related items.

## App
- Sidebar **Proposals** (count) shows the queue: rows with kind and target, the selected proposal's rationale, diff, model, label and citations. **A** accepts, **E** edits the added lines then accepts, **R** rejects (when the list has focus); buttons do the same. Footer: open count of 25, paused features, "Suggest Links".
- ⌘K: "Go to Proposals", "Suggest links for this week's notes".

## Files
`Packages/KBCore/Sources/KBCore/Proposal.swift`, `Packages/KBIndex/Sources/KBIndex/ProposalStore.swift`, `Packages/KBIndex/Sources/KBIndex/Related.swift`, `App/Proposals.swift`, `App/Shell/ProposalsView.swift`; tests `ProposalTests`, `ProposalStoreTests`, `RelatedTests`.

## Done when
- [x] Format round-trips; every kind applies or conflicts as above (KBCore tests).
- [x] Create, list, accept, edit, reject, conflict, cap, pause, duplicate refusal (KBIndex tests).
- [x] See-also on a scratch vault with the on-device model: two proposals with model-written reasons; the queue renders (`--snapshot … --select proposals` writes `*.proposals.png`).
- [ ] Gate: link-proposal acceptance ≥ 25% over your first month (`state.sqlite` `feature_events`).
