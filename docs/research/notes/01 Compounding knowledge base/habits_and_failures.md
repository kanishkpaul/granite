# Habits, Workflows, and Failure Modes of Long-Lived Obsidian / PKM Practice

Research scope: rituals and habits that make a personal knowledge base pay off over years, how notes become output, why people abandon PKM, how to measure payoff, and how newcomers should start. Methodology theory, vault structure, and plugins are covered by other researchers.

Source-quality note: Nearly all evidence here is practitioner self-report (blogs, forums, essays). I found **no systematic or longitudinal study** of Obsidian/PKM users. Several popular claims (e.g., Luhmann's "90,000 notes") are contested estimates. Some quotes below come from search-result summaries of pages rather than full-page fetches; these are marked "(via search summary)" and should be treated as lower confidence.

## 1. Review rituals: what long-term users actually do, how much time, and the minimum viable routine

### Takeaway
The most-cited long-term practitioner (Obsidian CEO Steph Ango) runs a deliberately lazy, low-friction routine: capture timestamped fragments as they occur, compile them every few days, review those monthly and yearly ("fractal journaling"), and do a random-note maintenance pass only every few months. No source I found quantifies time spent; the strongest pattern is that rituals are tiered (frequent tiny capture, infrequent consolidation) and optimized for speed rather than completeness.

### Cited Findings
- Steph Ango's daily notes contain nothing: they exist "solely to be linked to from other entries." He captures thoughts with a unique-note hotkey (timestamped `YYYY-MM-DD HHmm`). — [Steph Ango, "How I use Obsidian"](https://stephango.com/vault)
- Fractal journaling: every few days he compiles salient fragments into a review; reviews those reviews monthly; reviews the monthly reviews yearly using a "40 questions" template, producing "a fractal web of my life." — [Steph Ango](https://stephango.com/vault)
- Maintenance ritual: every few months he uses the random-note hotkey plus a shallow local graph to revisit old ideas, add missing links, and do maintenance. — [Steph Ango](https://stephango.com/vault)
- Linking habit: link the first mention of nearly everything, including unresolved links ("breadcrumbs for future connections"); use internal links "profusely." — [Steph Ango](https://stephango.com/vault)
- He wants a system "oriented towards speed and laziness" so he never has to decide where a note goes; most notes sit in the vault root; he keeps written personal rules (e.g., "Keep a single to-do list per week," use `YYYY-MM-DD` dates everywhere) and says "You can always change your rules later." — [Steph Ango](https://stephango.com/vault)
- Ango's page does not state how long he has used the system or how much time the rituals take. — [Steph Ango](https://stephango.com/vault)
- Ango's approach has been widely copied; one 2025 practitioner calls the post "incredibly influential in how I use Obsidian," and readers note he has since moved his demo vault to Obsidian Bases. — [Jered Sutton, "How I use Obsidian 2025"](https://jeredsutton-com.pages.dev/post/how-i-use-obsidian-2025); [secondary summary](https://second-brain-nuxt.vercel.app/how-i-use-obsidian)
- Andy Matuschak recommends processing collected material "in short cycles" rather than letting it pile up — a review cadence aimed at preventing backlog rather than auditing a large store. — [Matuschak, "Collecting material feels more useful than it usually is"](https://notes.andymatuschak.org/zQm6XAB3XXrXLHzF7gahpJ2)
- Simon Willison credits a weekly "weeknotes" habit with helping his publishing rhythm alongside TILs. — [Willison, "One year of TILs" (2021)](https://simonwillison.net/2021/May/2/one-year-of-tils)
- Counter-evidence on daily rituals: a practitioner whose Daily Note had a numeric KPI section and a free-text "Thoughts in my mind" section found the KPI section was filled every day while the thoughts section stayed empty, i.e., the ritual ran but produced no thinking. — [sho7650, "My Obsidian Vault Made 21 Permanent Notes in 3.5 Years" (dev.to, Oct 2026)](https://dev.to/sho7650/my-obsidian-vault-made-21-permanent-notes-in-35-years-so-i-redesigned-it-2229)

### Inferences
- A defensible "minimum viable routine" synthesized from these sources: (a) frictionless capture into one place (daily/unique note); (b) a short consolidation pass every few days or weekly that turns fragments into a few written claims or a review; (c) a monthly/quarterly pass that revisits random or old notes to add links and prune. Ango's practice suggests the quarterly maintenance can be light ("every few months").
- Rituals that record metrics (KPIs, checklists) are easy to sustain but can crowd out the rituals that matter (writing your own claims). A routine should be judged by what it produces, not whether it ran.
- Tiered reviews (days -> month -> year) reduce how much any single review must cover, which plausibly explains their durability.

### Gaps
- No source quantified actual minutes per day/week spent by long-term users; any time figures (e.g., "15 min/day") would be unsourced.
- Did not obtain Tiago Forte's weekly/monthly review guidance, Cal Newport's commentary, or r/ObsidianMD survey-style threads on review cadence within the tool-call budget.
- No data on how many users sustain a weekly review beyond the first year.

## 2. Turning notes into output: workflows and evidence that "write from your notes" works

### Takeaway
The evidence that notes drive output is mostly exemplary (Luhmann, Willison's TILs) and anecdotal; the best-documented case, Luhmann, shows a very low output-to-input ratio (roughly 1 book per 100 read, by a recent estimate), implying that output comes from selective, deep processing, not volume. Practitioner failures cluster around one missing step: writing your own claims. Lowering the bar for "done" (TILs, revisable permanent notes) is the most consistently reported fix.

### Cited Findings
- Luhmann's output figures are widely repeated (about 90,000 cards, 70+ books, ~400 articles) but disputed: a forum reconstruction estimates ~67,000 permanent notes plus ~15,000 literature notes (~82,000 total), and one summary notes Wikipedia cites ~50 books and ~550 articles. — [search summary incl. Tietze 2026 and Zettelkasten forum](https://forum.zettelkasten.de/discussion/comment/24808/) (via search summary)
- Christian Tietze (zettelkasten.de, March 2026), drawing on Edmund Gröpl's forum post: with ~67,000 notes and ~15,000 bibliographic entries, assuming a 50/50 books/articles split gives ~7,500 books read and "a bit over 70" books written, about 100 books read per book written, ~1% output per input; Tietze calls 1% "an interesting number to keep you humble." Gröpl suggests asking "how many books have grown out of what I read." These are explicitly estimates, and Tietze notes his own ~90k count doesn't match 67k + 15k. — [Tietze, "Zettelkasten Productivity: Books Written per Books Ingested"](https://christiantietze.de/posts/2026/03/zettelkasten-productivity-books-written-per-books-ingested/)
- Matuschak: understanding requires effortful engagement; the alternative to collecting is to "write about what you read," be selective because "most texts aren't worth writing detailed notes about," and use spaced repetition for small details. Linked notes include "Knowledge work should accrete" and "Evergreen note-writing helps reading efforts accumulate." — [Matuschak](https://notes.andymatuschak.org/zQm6XAB3XXrXLHzF7gahpJ2)
- Matuschak argues note-writing practices give weak, delayed, ambiguous feedback (unlike spaced repetition), so bad notes go unnoticed; evergreen notes that are constantly revised and consulted, and an "Executable strategy for writing," tighten the loop. He cites Ahrens (2017): bad note-taking produces "no immediate negative feedback." — [Matuschak, "Note-writing practices provide weak feedback"](https://notes.andymatuschak.org/Note-writing_practices_provide_weak_feedback)
- Simon Willison's TILs: after one year, 148 TILs across 43 topics. The format's value is that it drops "the barrier to publishing something online to almost nothing" (the bar is "did I just learn something?"), functioning as "a public notebook" and avoiding the unfinished drafts and sporadic publishing that originality pressure causes. — [Willison, "One year of TILs"](https://simonwillison.net/2021/May/2/one-year-of-tils)
- Willison later endorsed "write about what you learn" (2023) and in March 2026 added "beats" that pull TILs and other external content back into his blog homepage/search/archive, so notes resurface as part of his published record. — [Willison 2023](https://feeds.simonwillison.net/2023/Aug/14/write-about-what-you-learn/); [Willison 2026, "Beats now have notes"](https://simonwillison.net/2026/Mar/23/beats-now-have-notes/)
- Failure case with diagnosis: one Obsidian user produced only 21 permanent notes in ~3.5 years (since Feb 2023); 182 of 281 fleeting notes were unprocessed; recent 90-day inflow was 79 clippings, 142 AI conversations/summaries, and just 1 fleeting note. Diagnosis: the missing step was writing their own claims; adding tags and links did not create permanent notes; an "unshakable" quality bar meant notes were never finished. — [sho7650 (dev.to)](https://dev.to/sho7650/my-obsidian-vault-made-21-permanent-notes-in-35-years-so-i-redesigned-it-2229)
- Remedies in that redesign: redefine a permanent note as "correct as of the verification date, and revisable later" with six criteria (incl. one-sentence title, at least one piece of evidence); human writes claims and reasoning while AI only fact-checks, offers the strongest counterargument, and suggests related notes (it does not rewrite the body); add a "Today's one" slot in the daily note; do not bulk-process the backlog; set a concrete target (8 verified permanent notes in 4 weeks). — [sho7650 (dev.to)](https://dev.to/sho7650/my-obsidian-vault-made-21-permanent-notes-in-35-years-so-i-redesigned-it-2229)
- Jorge Arango (author of *Duly Noted*, 2024) recommends writing, structuring, and connecting ideas *as* thinking rather than mainly for later retrieval, and using AI as an "amanuensis" (collaborator, not ghostwriter); he lists nine AI roles from a year-long reading project (Tutor, Validator, Connector, Orienter, Recommender, Adversary, Analyst, Mapper, Reflector). — [Jorge Arango, "Robots in the Garden" (Mar 2026)](https://jarango.com/2026/03/27/robots-in-the-garden/)

### Inferences
- "Write from your notes" works when the vault contains the author's own claims in reusable form; stores of clippings and AI summaries do not convert to output on their own, no matter how well linked.
- Low-bar publishing formats (TILs, weeknotes, "revisable" permanent notes) seem to be the most reliable bridge from notes to output because they create the feedback Matuschak says note-taking lacks.
- Luhmann's ~1% ratio suggests newcomers should expect most captured material never to reach output, and should not treat that as failure.

### Gaps
- Did not retrieve primary text from Sönke Ahrens (beyond Matuschak's citation), Gwern's writing on long-form/long-content and revision, or Steph Ango's essays on writing (e.g., on publishing from his vault).
- No found documentation of academics quantifying papers produced from an Obsidian vault.
- No controlled evidence that "write from notes" outperforms other writing processes; all evidence is exemplary/anecdotal.

## 3. Failure modes and remedies

### Takeaway
The recurring failure modes are: collecting without processing (collector's fallacy), structure and tooling standing in for thinking (tinkering, plugins, nested folders), perfectionist quality bars, meaningless over-linking, backlog/inbox bankruptcy, and (newly) AI-generated filler entering the vault. The remedies that recur are: process in short cycles, write your own claims, lower the bar to "revisable," keep structure flat and let it emerge, limit plugins, and archive rather than migrate or bulk-process backlogs.

### Cited Findings
- **Collector's fallacy:** coined by Christian Tietze on zettelkasten.de (2014): having material at hand is mistaken for knowing it. — [Tietze, "The Collector's Fallacy"](https://www.zettelkasten.de/posts/collectors-fallacy). Tietze later confessed an Instapaper backlog of over 2,000 unread items. — [Tietze, "Collector's Fallacy Confession"](https://zettelkasten.de/posts/collectors-fallacy-confession/)
- Matuschak, citing Tietze: "having a text at hand does nothing to increase our knowledge"; collecting is often driven by anxiety about losing access and buries important material. Remedy: write about what you read, process in short cycles, be selective, use spaced repetition for small facts. — [Matuschak](https://notes.andymatuschak.org/zQm6XAB3XXrXLHzF7gahpJ2)
- **Structure replacing thinking / static categories:** Joan Westenberg (June 2025) deleted ~10,000 notes / 7 years of ideas; her system "began to replace" her thinking and "froze my curiosity into static categories." — [Westenberg via kottke.org](https://kottke.org/25/07/0047083-i-deleted-my-second-brain); original at [joanwestenberg.com](https://www.joanwestenberg.com/p/i-deleted-my-second-brain) (original page returned 404 on fetch; quotes via kottke)
- Arango quotes Westenberg that "a structure is not thinking," and her description of "deferral," pushing thinking off to a future self. — [Arango](https://jarango.com/2026/03/27/robots-in-the-garden/)
- **Over-engineered folders:** a 3-year Obsidian user found deep nested structures "create more problems than they solve" and their folder list shrank to a handful opened daily. — [MakeUseOf, "I wish I knew these before creating my Obsidian vault 3 years ago"](https://www.makeuseof.com/i-wish-i-knew-these-before-creating-my-obsidian-vault/) (via search summary). Ango keeps most notes in root and avoids nested subfolders. — [Ango](https://stephango.com/vault)
- **Tinkering and plugin bloat:** retrospective authors report spending early time on themes, plugins, and redrawing hierarchies instead of writing; a forum commenter notes thousands of notes won't slow a vault, "Plugins are usually the culprit." — [MakeUseOf](https://www.makeuseof.com/stopped-building-perfect-obsidian-vault-use-it-for-one-thing/); [Obsidian Forum](https://forum.obsidian.md/t/how-would-you-migrate-years-worth-of-notes-to-obsidian/111866) (via search summary)
- **Meaningless over-linking/over-capturing:** one user found after months of capturing everything that "my connections were meaningless" (trivial notes linked to trivial notes); remedy: ask whether a note will matter to your future self before creating it. — (via search summary, attributed among [MakeUseOf](https://www.makeuseof.com/i-wish-i-knew-these-before-creating-my-obsidian-vault/) / [XDA](https://www.xda-developers.com/gave-up-on-obsidian-twice-before-found-the-setup-that-stuck/) results; exact source page not confirmed). Note this partially conflicts with Ango's "link profusely" advice.
- **Inbox bankruptcy / backlog:** 182 of 281 fleeting notes unprocessed; the user explicitly decided *not* to bulk-process them and instead focused on producing new permanent notes going forward. — [sho7650](https://dev.to/sho7650/my-obsidian-vault-made-21-permanent-notes-in-35-years-so-i-redesigned-it-2229)
- **Perfectionism:** an "unshakable intelligence" bar meant permanent notes were never finished; remedy: "correct as of the verification date, and revisable later." — [sho7650](https://dev.to/sho7650/my-obsidian-vault-made-21-permanent-notes-in-35-years-so-i-redesigned-it-2229). Willison's TIL format exists to avoid originality pressure that produces unfinished drafts. — [Willison](https://simonwillison.net/2021/May/2/one-year-of-tils)
- **AI-generated filler:** 142 of the user's recent 90-day inflow items were AI conversations/summaries; some fleeting notes contained pasted AI boilerplate (e.g., "Thank you for your understanding"). Remedy: human writes claims; AI only verifies, argues against, and suggests links. — [sho7650](https://dev.to/sho7650/my-obsidian-vault-made-21-permanent-notes-in-35-years-so-i-redesigned-it-2229). Arango similarly positions AI as collaborator, not ghostwriter. — [Arango](https://jarango.com/2026/03/27/robots-in-the-garden/)
- **Repeated migration / vault sprawl:** a user migrating thousands of notes merged separate per-notebook vaults into one, importing old material into an `Archive/` subfolder inside the main vault so it stays searchable but out of the way. — [Obsidian Forum](https://forum.obsidian.md/t/how-would-you-migrate-years-worth-of-notes-to-obsidian/111866) (via search summary)
- **Using the tool too much:** an XDA writer abandoned Obsidian twice; it finally stuck when they used it less, opening it for specific tasks (e.g., studying) and letting other tools handle the rest. — [XDA](https://www.xda-developers.com/gave-up-on-obsidian-twice-before-found-the-setup-that-stuck/) (via search summary). A MakeUseOf writer similarly stopped building the "perfect vault" and used it for one thing. — [MakeUseOf](https://www.makeuseof.com/stopped-building-perfect-obsidian-vault-use-it-for-one-thing/)
- **Weak feedback as root cause:** bad notes produce no immediate negative signal, so failure modes persist unnoticed. — [Matuschak](https://notes.andymatuschak.org/Note-writing_practices_provide_weak_feedback)

### Inferences
- Most failure modes share one root: activity that feels productive (capturing, linking, organizing, configuring, AI summarizing) substitutes for writing your own thoughts. Remedies work by forcing a small, frequent act of authorship.
- Link discipline is contested: Ango's "link the first mention of everything" succeeds within a lazy, fast system, while others found indiscriminate links meaningless. The difference may be whether links are a byproduct of writing (cheap, fine) or a maintenance goal in themselves (costly, empty).
- Declaring backlog bankruptcy (archive, don't process) appears to be a healthier response than either deleting everything (Westenberg) or grinding through it.

### Gaps
- No found sources specifically on link rot (broken external URLs) or tag proliferation in long-lived Obsidian vaults within budget.
- No quantitative data on how common each failure mode is.

## 4. Why people abandon PKM / "second brains": critiques and implications

### Takeaway
The 2025-2026 wave of critiques (Westenberg's "I Deleted My Second Brain" and responses) centers on the "second brain" framing: outsourcing thinking and memory to a system leads to deferral, static categories, and maintenance burden. Defenders (e.g., Jorge Arango) accept the diagnosis but blame the metaphor, recommending a "garden"/place-for-thinking framing with slow, emergent growth.

### Cited Findings
- Westenberg (June 16, 2025) deleted ~10,000 notes and 7 years of ideas; she argued the system replaced thinking rather than accelerating it. — [kottke.org](https://kottke.org/25/07/0047083-i-deleted-my-second-brain); [search summary of essay](https://www.joanwestenberg.com/i-deleted-my-second-brain-692aa40d59d5f06dd5131e43) (her reading list was also deleted and she says she lost nothing real; via search summary). The vault was reportedly in Obsidian per Akhil Unnikrishnan, though kottke says the essay itself doesn't name the tool. — [Akhil Unnikrishnan](https://akhiluk.bearblog.dev/2025/07/a-second-brain-was-never-really-feasible/) (via search summary; page 404 on fetch); [kottke.org](https://kottke.org/25/07/0047083-i-deleted-my-second-brain)
- Responses: Derek Kedziora reached the same conclusions but didn't delete everything; Akhil Unnikrishnan argued a second brain "was never really feasible," tracing PKM culture to systems theory, quantified self, and Silicon Valley "productivity as life." — [Kedziora](https://scour.ing/p/https://derekkedziora.com/notes/2025-06-30-also-done-with-second-braining); [Unnikrishnan](https://akhiluk.bearblog.dev/2025/07/a-second-brain-was-never-really-feasible/) (via search summaries). A counterpoint, "Why I'm not deleting everything," appeared in June 2025. — [Conferences That Work](https://www.conferencesthatwork.com/index.php/personal-effectiveness/2025/06/deleting/) (title only seen)
- Arango (Mar 2026): the "second brain" metaphor sets people up for disappointment by suggesting delegated thinking/recall, which tools can't deliver and isn't a good goal; proposes a "knowledge garden" valued for process as well as output; notes earlier critiques like "Personal Knowledge Management Is Exhausting." — [Arango](https://jarango.com/2026/03/27/robots-in-the-garden/)
- Other critiques: Baldur Bjarnason argues the effort of maintaining elaborate linking systems often exceeds the benefits ("productivity theater") and that external notes can't replicate memory; others describe PKM as a "nerd snipe" for organized people and a form of procrastination; Glen Rhodes names a "hard drive fallacy" (write, store, retrieve later). — [HackerNoon, "The illusion of personal knowledge management"](https://hackernoon.com/the-illusion-of-personal-knowledge-management); [Seeking Tribe "The Note Taking Nerd Snipe"](https://hn.jakechampion.name/reader/https://www.seekingtribe.com/p/our-embarrassment-of-riches-information); [Glen Rhodes](https://glenrhodes.com/?p=1790) (all via search summary; Bjarnason attribution via a secondary source, original essay not fetched)
- Defender view: Tiago Forte frames Building a Second Brain as designed to address common PKM failure modes. — [Forte Labs](https://fortelabs.com/blog/all-things-second-brain-productivityist/) (via search summary)

### Inferences
- Abandonment correlates with treating the vault as a destination (a store to maintain) rather than a workshop for current projects. Critics and defenders converge: notes pay off when they're used for thinking now, not stockpiled for a hypothetical future self.
- Westenberg's "deferral" concept is a useful diagnostic: if a vault's main effect is postponing thinking ("I'll process this later"), it is failing regardless of size.
- Total deletion and "starting fresh" are themselves a variant of the migration/reset failure mode; archiving achieves the psychological reset without losing a searchable record.

### Gaps
- Could not fetch Westenberg's original essay (404) or Bjarnason's original; some details rely on secondary quotes.
- No data on abandonment rates (e.g., how many Obsidian users stop within a year). Claims like "digital brains die in 90 days" (seen in a search title) are unsourced marketing and should not be used.

## 5. Measuring whether a vault pays off

### Takeaway
No established metrics exist in the sources; practitioners improvise. The most useful proxies found are output-oriented: count of self-authored claim notes produced per period, ratio of output to input (Gröpl/Tietze's "books grown out of what I read"), and inflow composition (own writing vs. clippings/AI). Ango's and Willison's practices imply a retrieval/resurfacing test.

### Cited Findings
- Gröpl/Tietze propose measuring "how many books have grown out of what I read," i.e., output per input (~1% for Luhmann, estimated), and judging a Zettelkasten by depth of digestion rather than throughput. Tietze plans tooling to count unprocessed sources. — [Tietze 2026](https://christiantietze.de/posts/2026/03/zettelkasten-productivity-books-written-per-books-ingested/)
- Practitioner audit metrics used: number of permanent notes over time (21 in 3.5 years), last-updated dates (none in 90 days), fleeting-note processing rate (99/281), 90-day inflow mix by type; success metric set as 8 verified permanent notes in 4 weeks. The audit was done with Claude Code reading the vault. — [sho7650](https://dev.to/sho7650/my-obsidian-vault-made-21-permanent-notes-in-35-years-so-i-redesigned-it-2229)
- Arango's "Reflector" AI role analyzes one's notes over time to reveal patterns, a qualitative self-audit. — [Arango](https://jarango.com/2026/03/27/robots-in-the-garden/)
- Willison's 148 TILs / 43 topics in year one is a simple published-output count. — [Willison](https://simonwillison.net/2021/May/2/one-year-of-tils)

### Inferences
- Candidate metric set for a report: (1) self-authored notes created/revised per month; (2) share of inflow that is own writing vs. clipped/AI; (3) notes cited or linked in finished outputs (essays, decisions, code docs); (4) backlog age; (5) periodic retrieval test: can you find what you need in under a minute? (3) and (5) are inferences, not found in sources.
- Matuschak's weak-feedback argument implies any explicit metric is better than none, since the default is no signal.

### Gaps
- No sources found on "reuse rate" or "retrieval success" as formal metrics, nor tooling that measures notes linked in output. These remain open.

## 6. How a newcomer should start: minimal setup vs. upfront design

### Takeaway
Sources consistently favor starting minimal and letting structure emerge: flat folders, a few written personal rules, frictionless capture, and one concrete use case, revising rules as needed. Upfront taxonomy design and heavy plugin setup are repeatedly identified as early-stage traps.

### Cited Findings
- Ango: choose rules that feel comfortable, write them down, change them later; take "the parts you like" rather than copying dogmatically; prefer speed and laziness over deciding where notes go. — [Ango](https://stephango.com/vault)
- Arango: let structure emerge over time rather than imposing workflows up front; expect slow, long-term returns. — [Arango](https://jarango.com/2026/03/27/robots-in-the-garden/)
- Retrospectives: nested hierarchies and early theme/plugin tinkering were regretted; a vault stuck when used "for one thing" or for specific tasks. — [MakeUseOf (3 years)](https://www.makeuseof.com/i-wish-i-knew-these-before-creating-my-obsidian-vault/); [MakeUseOf (one thing)](https://www.makeuseof.com/stopped-building-perfect-obsidian-vault-use-it-for-one-thing/); [XDA](https://www.xda-developers.com/gave-up-on-obsidian-twice-before-found-the-setup-that-stuck/) (via search summary)
- Matuschak: be selective from the start; most texts don't deserve detailed notes. — [Matuschak](https://notes.andymatuschak.org/zQm6XAB3XXrXLHzF7gahpJ2)
- Willison: adopt a low-bar output format early (TILs) so writing happens immediately. — [Willison](https://simonwillison.net/2021/May/2/one-year-of-tils)
- AI-era setup: some 2026 practitioners put a `CLAUDE.md` at the vault root describing conventions so Claude Code can work on the vault (e.g., Kenneth Reitz). — [Kenneth Reitz, "Obsidian Vaults & Claude Code" (Mar 2026)](https://kennethreitz.org/essays/2026-03-06-obsidian_vaults_and_claude_code) (via search summary); Ango has published Claude Code skills for vault work. — [secondary review](https://eliteaiadvantage.com/reviews/obsidian-skills-kepano) (via search summary)

### Inferences
- A reasonable newcomer path: week 1, one vault, root folder plus a couple of admin folders, daily note + capture hotkey, write a 5-line rules note; month 1, start a low-bar output stream (TILs, weekly review, or one project's notes); quarter 1, first random-note maintenance pass and first audit of inflow mix; add plugins only when a specific repeated pain appears.
- Starting with a single real project or question gives the feedback loop that pure "knowledge collection" lacks.
- When adding AI agents, assign them verification/linking roles and keep authorship human to avoid the filler failure mode.

### Gaps
- No comparative evidence (only opinion) that minimal-start users persist longer than upfront designers.
- Did not survey r/ObsidianMD, r/PKMS, or r/Zettelkasten newcomer-advice threads directly within the tool budget.
