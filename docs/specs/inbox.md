# Spec: Inbox decide queue, rename and move (phase 1, item 5)

Status: **built**. Plan refs: §7 feature 3 ("items older than 14 days go to a decide queue … a bankruptcy button moves everything older than 60 days to `Archive/`"), §2 principle 8, §11 backlog age.

## Rename and move (`KBCore.SafeWriter.move`, `KBIndex.RenameService`)
- `move(from:to:as:)` is coordinated (`NSFileCoordinator`), creates folders, never overwrites, and the `.ai` role may only move within `AI/`.
- `RenameService.rename(from:to:)` moves the note, then rewrites every link to it in other notes, found through the index (`links` rows whose `dst` is the note):
  - wikilinks and embeds: the target part changes; `#heading`, `#^block` and `|alias` are kept;
  - frontmatter relations (`supports: ["[[Old]]"]`) the same way;
  - Markdown links `[x](../Old.md#Part)`: the relative path is recomputed from the linking note's folder;
  - only lines the index recorded as holding the link are touched, so code blocks and prose that merely mention the name are left alone;
  - a bare-name link stays bare when the new name is unique; a path-style link gets the new path.
- All rewritten files go through `SafeWriter` (role `.user`: a rename is your action), then the index updates them.

## Inbox queue (`KBCapture.InboxQueue`)
- An item's age comes from its frontmatter `created`, else the `YYYY-MM-DD HHmm` file name, else the file's modification time.
- **Decide queue:** items older than 14 days. Each gets one of:
  - **Make note:** rename to `Notes/<title>.md` (links rewritten), `kind: capture` → `kind: evergreen`.
  - **Append to note:** the capture's body is appended to an existing note under `## From inbox, YYYY-MM-DD`, then the capture is archived.
  - **Archive:** move to `Archive/Inbox/`.
- **Bankruptcy:** every item older than 60 days moves to `Archive/Inbox/` in one step, after a confirmation listing the count.
- Median Inbox age is reported (metric for phase 3, target < 14 days).

## App
- Inbox in the sidebar shows the decide queue first (items > 14 days, oldest first, with the "why" line), then newer items; actions on each row; "Declare bankruptcy" when anything is older than 60 days.
- Commands: Rename Note… and Move Note to Folder… (palette and Go menu), both through `RenameService`.

## Done when
- [x] Tests: coordinated move rules; rename rewriting wikilinks, embeds, anchors, aliases, frontmatter relations, relative Markdown links; code blocks untouched; path-style links; index updated; Inbox ages, queue, make-note, append, archive, bankruptcy.
