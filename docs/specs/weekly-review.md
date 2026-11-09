# Spec: weekly Socratic review

Status: **built**. Plan refs: §7 idea 11, §8 phase 3, §11 cadence.

## Inputs
- The week: daily notes, held claims with `as_of` this week, inbox size, open proposals, notes changed.
- Your answers to four questions, asked before anything else:
  1. What changed your mind this week?
  2. Which claim would you defend least, and why?
  3. What did you capture that you haven't made sense of yet?
  4. What will you think about next week?

## Outputs
- `Daily/YYYY-Www.md` (`type: daily`, `kind: weekly`, `origin: human`): one section per answered question. Saving again appends under the same questions; your own edits stay.
- "Challenge me" (optional, per answer): grounded Q&A in Socratic mode, retrieving by what you wrote, so it shows verified passages from your notes that support or complicate your view. Shown in the sheet only; nothing a model wrote is saved to the note. Logged in `qa_log` as `weekly-review`.

## Rules
- The session is judged by what you wrote, not whether it ran: the weekly-review metric counts saved notes (`feature_events`, `weekly-review`).
- The sidebar "Weekly Review" shows a dot on Saturdays and Sundays until this week's note exists.

## Files
`Packages/KBCore/Sources/KBCore/WeeklyNote.swift`, `App/Review/WeeklyReview.swift`, `App/Review/WeeklyReviewView.swift`; tests `WeeklyNoteTests`.

## Done when
- [x] ISO weeks, rendering and appending (tests).
- [x] Scratch vault, on-device: a challenge returned 2/2 verified counter-points; the saved note holds only the answer (`--weekly "…"`).
- [ ] Gate (phase 3): four consecutive weekly reviews (you).
