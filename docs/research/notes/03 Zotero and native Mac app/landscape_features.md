# Landscape Feature Teardown: Knowledge-Base and Research Tools (as of Nov 2026), for a Personal Native Mac Knowledge App

Scope note: This is a feature-level teardown, not a product roundup. Zotero, the Mac stack and AI architecture are covered elsewhere. About 20 searches were run. Source quality is uneven: much 2026 coverage is SEO, affiliate or AI-generated review sites, so primary sources (vendor pages, Matuschak's notes, the FSRS benchmark) are weighted more heavily. Each finding is tagged with how reliable its source is.

---

## Q1. Which features have evidence, or strong long-term user sentiment, of compounding value?

### Takeaway
Only one candidate has hard quantitative evidence: spaced repetition with a modern scheduler (FSRS), backed by a benchmark of about 729M reviews. Typed objects, AI Q&A grounded in citations, citation-graph discovery and "See Also" similarity have strong but anecdotal sentiment. Resurfacing (Readwise daily review) is loved as a habit, but no one has measured whether it pays off over years. Canvas thinking and lifelogging help in specific phases of work but do not compound reliably on their own.

### Cited Findings

**Spaced repetition / FSRS (strongest evidence)**
- The open SRS benchmark compares schedulers on how well they predict recall (RMSE, log loss) over 19,993 collections and 728,883,020 reviews. A forum user quoting it says FSRS-5 beats a *trainable* SM-2 in 97.4% of collections. — [Expertium Benchmark](https://expertium.github.io/Benchmark.html); [Anki forum thread](https://forums.ankiweb.net/t/fsrs-vs-sm2-in-2-seperate-profiles/52171)
- Caveat: SM-2 was never built to predict probabilities, so the benchmark adds formulas to make it comparable, and uses the original SM-2 rather than Anki's variant. — [Expertium Benchmark](https://expertium.github.io/Benchmark.html)
- Widely repeated claims that FSRS needs "20–30%" or "15–40%" fewer reviews for the same retention are *not verified*. At least one source says its own numbers are illustrative. — [lumenlabs article](https://lumenlabs-website.pages.dev/article/recall/fsrs-vs-sm-2-what-changed-and-why-it-matters/) (low reliability)
- The mnemonic medium (spaced-repetition prompts embedded in prose; Quantum Country, then Orbit): Matuschak's notes say mnemonic essays may give detailed retention of their contents "in exchange for 35–50% reading time overhead", with substantial room to reduce that. — [Matuschak, Mnemonic medium](https://notes.andymatuschak.org/Mnemonic_medium)
- Matuschak calls Orbit his platform for experiments in "Mnemonic medium, Programmable attention, etc." and says he is deliberately *not* trying to scale it rapidly. — [Matuschak, Orbit](https://notes.andymatuschak.org/Orbit); [Aggressively scaling the mnemonic medium in 2020 is premature](https://notes.andymatuschak.org/zAMGD5ZWBpmzRD3tMgVqfg1)
- The underlying argument ("Why books don't work"): books are surprisingly bad at conveying knowledge, and readers mostly don't notice. — [Readwise copy of the essay](https://anagora.org/raw/garden/protopian/Readwise/Articles/Why%20books%20don%E2%80%99t%20work.md); [SuperMemo wiki commentary](https://supermemo.guru/wiki/Books_don't_work)

**Resurfacing (Readwise daily review)**
- Evidence is anecdotal. One user reports 20 months of daily use as a habit ([mickmel.com](https://www.mickmel.com/a-little-readwise-every-day)). Another found it "a bit more useful once they started using it regularly" after ignoring the emails at first ([purplestories substack](https://purplestories.substack.com/p/using-tools-to-improve-your-reading)).
- A Medium reviewer found it hard to justify for fiction-heavy reading but "really useful" for nonfiction. — [Robbie Adler, Medium](https://medium.com/@robbieadler/a-not-so-short-readwise-reader-review-dd46dbc98785)
- Price friction: about $12.99/month for the full plan. — [techpresso review](https://academy.techpresso.co/reviews/is-readwise-reader-worth-it) (secondary)
- No found source tests whether resurfacing old highlights pays off *years* later. — [search summary of the above sources]

**Classification / semantic "See Also" (DEVONthink)**
- DEVONtechnologies says its own non-generative AI has been the core of the apps since 1.0, powering search and the contextual See Also inspector. DEVONthink 4 adds generative AI that is opt-in and supports local models via Ollama and LM Studio. — [DEVONtechnologies "New in DEVONthink 4"](https://devontechnologies.com/apps/devonthink/new); [DEVONtechnologies blog](https://devontechnologies.com/blog/20250717-devonthink-ai-app)
- A Chinese review (sspai) says DT4 mostly reorganized and refined See Also and classification rather than changing them fundamentally. — [sspai](https://sspai.com/post/100991)
- Inspector layout described by reviewers: an AI tab with See Also (recommends related items in your database), Tags (suggested tags) and Graph (visualized connections). — [MacStories DT4 review](https://www.macstories.net/reviews/ai-adds-a-new-dimension-to-devonthink-4/) (sponsored)
- The candid caveat, in a *sponsored* MacStories review: See Also and Graph are "interesting alternatives to traditional search," but the reviewer hadn't found himself using them much. — [MacStories](https://www.macstories.net/reviews/ai-adds-a-new-dimension-to-devonthink-4/)
- DT4 can run AI inside smart rules, for example to summarize new unread items automatically. DT4 also added automatic versioning. — [MacSparky (sponsored)](https://www.macsparky.com/blog/2025/06/devonthink-4-beta-ai-that-makes-sense-for-power-users-sponsor/); [AlternativeTo news](https://alternativeto.net/news/2025/6/devonthink-4-copernicus-adds-ai-model-integration-automatic-versioning-and-smarter-search)

**Typed objects / supertags (Tana, Capacities, Logseq DB, Anytype)**
- Tana supertags are described as giving "the power of a database in our notes." The main complaint is a "real learning curve," along with requests for better mobile, API and integrations. — [Product Hunt Tana reviews](https://www.producthunt.com/products/tana/reviews)
- Tana's own idea board has requests to simplify supertag configuration, noting it "creates a steep learning curve," and asking for multiple templates per supertag. — [Tana ideas board](https://ideas.tana.inc/posts/526-quick-select-the-main-tag-or-drag-and-drop-to-switch-supertag-order)
- A secondary claim, not verified: the most-upvoted r/Tana and r/PKMS threads call supertags "life-changing for research" while complaining about the "onboarding cliff." — [doolpa.com](https://doolpa.com/article/tana) (low reliability)
- Capacities' typed objects (Book, Person, Project, etc., each with its own properties, plus custom types) are its main draw. "Some people love the structure, others find it restrictive." — [blog.saner.ai Capacities review](https://blog.saner.ai/capacities-review); [atlasworkspace comparison](https://www.atlasworkspace.ai/blog/obsidian-vs-capacities) (competitor-authored)
- Obsidian users have asked for "strong object typing" as a core feature, which shows typed objects pulling users away from plain markdown. — [Obsidian forum: Strong Object Typing](https://forum.obsidian.md/t/strong-object-typing/117966)
- Logseq's DB version (its move to typed properties and tags) entered beta only in July 2026 (2.0.1). The README reportedly warns that data loss is possible, and mobile and real-time sync are still alpha. — [GitClear 2.0.1](https://www.gitclear.com/open_repos/logseq/logseq/release/2.0.1); [PromptQuorum review](https://www.promptquorum.com/power-local-llm/logseq-review) (single source on 2.0.2 / Oct 2026)
- Logseq DB's "Markdown Mirror" exports the DB graph to disk, but two-way sync (markdown edits flowing back in) was still unshipped as of May 2026. — [Logseq forum, May 16 2026](https://discuss.logseq.com/t/whats-new-with-logseq-db-may-16th-2026/35020)

**Canvas / whiteboard thinking (Heptabase, Scrintal, Muse)**
- In a few-week hands-on test, Heptabase's whiteboard helped with a literature review and suits open-ended synthesis. However, "a big whiteboard can sprawl into a mess that takes as long to tidy as the thinking it was supposed to support." — [dev.to Heptabase review](https://dev.to/pickuma/heptabase-review-visual-note-taking-for-thinking-through-problems-5daa)
- Product Hunt reviewers praise cards plus whiteboards for organizing research, but report lag on large whiteboards and heavy PDF use, weak task handling, and UI rough edges. — [Product Hunt Heptabase reviews](https://www.producthunt.com/products/heptabase/reviews)
- No formal long-term study of canvas tools was found.

**Citation graphs / automatic literature maps**
- Litmaps acquired ResearchRabbit (May 2025, plus about $1M raise) and plans to merge their features. A revamped ResearchRabbit launched Oct 30, 2025, with a Litmaps-like UI. Aaron Tay frames the revamp around "iterative chaining without the clutter." — [IT Brief NZ](https://itbrief.co.nz/story/litmaps-acquires-researchrabbit-raises-1-million-for-ai); [ResearchRabbit release notes](https://www.researchrabbit.ai/releases/welcome-to-the-new-researchrabbit); [Aaron Tay](https://aarontay.substack.com/p/researchrabbits-2025-revamp-iterative)
- One directory claims ResearchRabbit moved from free to freemium (RR+ about $10/mo) in Q3 2026. Unverified. — [AI Agent Index](https://theaiagentindex.com/agents/researchrabbit) (low reliability)

**AI Q&A with citations (NotebookLM, Elicit, Consensus)**
- NotebookLM's core is source-grounded answers with clickable citations back to source passages. The June 2026 Gemini 3.5 upgrade added agentic tool use (finding sources via Google Search, code execution, downloadable outputs). — [EdTech Innovation Hub](https://www.edtechinnovationhub.com/news/google-upgrades-notebooklm-with-gemini-35-and-agentic-research-tools); [WinBuzzer, Jun 9 2026](https://winbuzzer.com/2026/06/09/google-adds-gemini-35-and-antigravity-to-notebooklm-xcxwbn/)
- Elicit's search recall: a comparison page cites two (unnamed) peer-reviewed studies putting Elicit's sensitivity at about 39–40%, versus about 94.5% for traditional systematic-review searching. It says Consensus has no independent accuracy study, and that Consensus's "Consensus Meter" counts papers without weighting by study design. — [CASRAI compare](https://casrai.org/compare/elicit-vs-consensus) (studies not named, so treat as unverified)
- In an informal reviewer test, Consensus linked claims to sources while Elicit sometimes produced unsupported claims. This is a single-reviewer test. — [CO/AI](https://getcoai.com/video/i-tested-3-literature-review-ais-only-one-didnt-lie-to-me/)
- Elicit's own support page addresses hallucination risk (vendor source). — [Elicit support](https://support.elicit.com/en/articles/552897)

**Meeting capture / lifelog**
- Granola's loved feature is *hybrid* notes: the user types rough notes, and AI merges them with a local-audio transcript, with no bot joining the call. In April 2026, Chat was rebuilt as an agent that searches months or years of notes and transcripts with inline citations. Drawback: Granola doesn't keep full audio, so exact quotes can't be checked. — [skillscouter review](https://skillscouter.com/granola-review/); [aitoolsatlas](https://aitoolsatlas.ai/tools/granola/review) (secondary)
- Rewind: Meta acquired Limitless (Dec 5, 2025), and the Rewind Mac app's screen and audio capture shut off on Dec 19, 2025. — [9to5Mac](https://9to5mac.com/2025/12/05/rewind-limitless-meta-acquisition/); [Littlebird](https://littlebird.ai/blog/rewind-alternatives)
- Screenpipe (open source, on-device, cross-platform) is the most-cited successor. Most sources making that claim are competitor or Screenpipe marketing. — [screenpi.pe blog](https://screenpi.pe/blog/rewind-ai-alternative-2026); [usecarly](https://www.usecarly.com/blog/rewind-ai-alternatives/)

### Inferences
- Value compounds only when the system *does something with* old material without the user having to remember it: scheduling it (SRS), surfacing it in context (See Also), linking it (citation graph), or answering from it (grounded Q&A). Features that only store or display (big canvases, raw lifelogs) don't compound unless paired with retrieval.
- FSRS is a solved, open, well-benchmarked component (open-source implementations exist). A custom app should adopt it rather than invent a scheduler, and spend its design effort on *what* gets turned into prompts. That is Matuschak's point: the bottleneck is prompt authoring and its reading overhead, not the algorithm.
- DEVONthink's 20-year-old See Also is the best existence proof that local, non-generative similarity can be useful. The MacStories admission ("haven't used them much") suggests it fails when shown only in a side inspector the user must open. Proactive, inline surfacing is probably what makes it pay off.
- Granola's success suggests the winning capture pattern is human-in-the-loop augmentation (your sparse notes plus a machine record), not passive total capture.

### Gaps
- No longitudinal study found on whether resurfacing (Readwise-style) improves recall or creative output over years.
- No independent quantitative study found on typed objects, canvas tools or See Also features.
- No primary FSRS figure for "% fewer reviews at equal retention." The often-quoted 20–30% is unverified.
- Recall (getrecall.ai), Scholarcy, Semantic Scholar's 2026 features (TLDRs, Semantic Reader) and Connected Papers' 2026 status were not researched within the budget.
- Essays by Linus Lee and Maggie Appleton and academic HCI tools-for-thought work were not retrieved. Their arguments are not cited here.

---

## Q2. What do power users complain about or abandon?

### Takeaway
The dominant failure is behavioral, not technical: the "collector's fallacy" (capture without processing) produces note graveyards and periodic "I deleted my second brain" purges. The technical complaints are complexity or onboarding cliffs (Tana), sprawl and lag (Heptabase canvases), beta-stage data risk (Logseq DB), AI that fabricates or misses sources (Elicit recall), subscription stacking, and vendor death or acquisition (Rewind, Omnivore). Durable local files ("file over app") is the strongest counter-sentiment.

### Cited Findings
- "Collector's fallacy" (Christian Tietze): confusing collecting information with understanding it. It was discussed on HN in 2018. — [Zettelkasten forum](https://forum.zettelkasten.de/discussion/comment/1067/); [Goodluckman substack](https://goodluckman.substack.com/p/the-collectors-fallacy-why-most-notetaking)
- Joan Westenberg's "I deleted my second brain" (deleting a long-running PKM system as a response to anxiety and overload) sparked wide HN discussion. — [Westenberg](https://www.joanwestenberg.com/i-deleted-my-second-brain-692aa40d59d5f06dd5131e43); [forum summary](https://imron.netlify.app/forum-summary/i-deleted-my-second-brain)
- Another failure account: "a second brain was never really feasible." — [Akhil Unnikrishnan](https://akhiluk.bearblog.dev/2025/07/a-second-brain-was-never-really-feasible/). Also "2 years, 2,094 notes: the Obsidian reality check." — [digitalbiztalk](https://digitalbiztalk.com/article/2-years-2094-notes-the-obsidian-reality-check)
- Recommended antidote: "a bias toward processing over saving." — [dsebastien PKM anti-patterns](https://www.dsebastien.net/ai-wiki-pkm-pkm-anti-patterns/)
- Tana: learning curve and onboarding, weak mobile, API and integration gaps. — [Product Hunt Tana](https://www.producthunt.com/products/tana/reviews)
- Heptabase: whiteboard sprawl, lag on large boards and PDFs. — [dev.to](https://dev.to/pickuma/heptabase-review-visual-note-taking-for-thinking-through-problems-5daa); [Product Hunt](https://www.producthunt.com/products/heptabase/reviews)
- Capacities: structure can feel restrictive. The trade-off is file ownership against built-in structure and managed sync. — [saner.ai](https://blog.saner.ai/capacities-review); [atlasworkspace](https://www.atlasworkspace.ai/blog/obsidian-vs-capacities)
- Logseq DB: beta with possible data loss, and mobile and sync in alpha, more than a year after the DB rewrite was announced. Two-way markdown sync is unshipped. — [PromptQuorum](https://www.promptquorum.com/power-local-llm/logseq-review); [Logseq forum](https://discuss.logseq.com/t/whats-new-with-logseq-db-may-16th-2026/35020)
- AI research tools: Elicit's reported search sensitivity is about 39–40% ([CASRAI](https://casrai.org/compare/elicit-vs-consensus), unverified studies), and an informal test found fabricated or unsupported claims ([CO/AI](https://getcoai.com/video/i-tested-3-literature-review-ais-only-one-didnt-lie-to-me/)). A PRISMA-based study of ChatGPT for literature review reported hallucination rates of 28–91% across tasks. — [devdiscourse summary](https://www.devdiscourse.com/article/technology/3467743-ai-hallucination-crisis-chatgpt-excels-in-speed-but-flounders-in-scholarly-rigor)
- Lock-in and vendor death: Rewind was shut down after the Meta–Limitless deal ([9to5Mac](https://9to5mac.com/2025/12/05/rewind-limitless-meta-acquisition/)). Omnivore's hosted service ended in November 2024; the code remains open source and a community fork exists ([yaps.ai](https://www.yaps.ai/blog/omnivore-alternative.md); [mailist comparison](https://mailist.app/blog/mailist-vs-omnivore)). One single-source claim says Pocket also closed in 2025 ([yaps.ai](https://www.yaps.ai/blog/omnivore-alternative.md)).
- "File over app" (Steph Ango / Obsidian): store data in durable open formats that outlive the app, and accept that all software is ephemeral. Commentators note that some Obsidian power comes from plugins and features that violate this. — [Steph Ango (original)](https://stephango.com/file-over-app); [dsebastien notes](https://notes.dsebastien.net/30+Areas/33+Permanent+notes/33.02+Content/File+over+app+principle); [snowan analysis](https://snowan.gitbook.io/study-notes/ai/ai-article-analysis/file-over-app/file-over-app-analysis)
- Subscription stacking, as an example: Readwise full plan about $12.99/mo ([techpresso](https://academy.techpresso.co/reviews/is-readwise-reader-worth-it)); Granola Business about $14/user/mo for unlimited history ([skillscouter](https://skillscouter.com/granola-review/)); Mem Pro reportedly $12/mo (unverified, [yespress](https://yespress.io/mem)).
- Mem, an earlier "AI-first notes" darling, pivoted and relaunched as Mem 2.0 (Oct 2, 2025: offline-first, voice capture, agentic chat, "Heads Up" recall). It now positions itself as a "thought partner" rather than a notes app. — [AlternativeTo](https://alternativeto.net/news/2025/10/mem-2-0-relaunches-with-smarter-note-taking-tools-offline-support-and-a-new-agentic-chat); [Product Hunt](https://www.producthunt.com/products/mem-2-0)

### Inferences
- A personal app must design against the collector's fallacy. Every capture path should nudge, cheaply, toward one act of processing: a one-line "why I saved this," a link to a question, or a prompt. Otherwise the app becomes the graveyard people later delete.
- The repeated shutdowns (Rewind, Omnivore, Pocket per one source) and Logseq's multi-year migration risk are concrete arguments for a local-first, open-format store that you own. This is a natural advantage of a custom native app.
- Complexity complaints (Tana, Capacities) are mostly about *configuring* schemas before getting value. A single-user app avoids the general-purpose configuration UI by hard-coding the handful of types the owner actually uses (Paper, Clip, Note/Idea, Project, Decision, Person) and letting schemas grow from usage.
- AI hallucination complaints concentrate where the AI *searches the open world* (Elicit, ChatGPT). Grounding answers in the user's own corpus with passage-level citations (the NotebookLM and Granola Chat pattern) is the defensible pattern.

### Gaps
- Could not retrieve r/PKMS, r/ObsidianMD, r/DEVONthink or r/Zotero threads directly, so the Reddit sentiment here is second-hand.
- Status of Muse, Napkin, Scrintal, Reflect, Bear, Craft and Anytype in Nov 2026 is unverified. Searches returned nothing on Muse or Napkin shutdowns. Defunct status should be checked before the final report names them.
- No quantitative data found on PKM tool churn or abandonment rates.

---

## Q3. What is missing in the market that a personal custom app could uniquely do (including code and project knowledge)?

### Takeaway
No product found links papers to ideas to code decisions in one typed graph with provenance. Research tools (Elicit, Litmaps, NotebookLM) stop at the literature, PKM tools (Tana, Capacities, Obsidian) stop at notes, and developer memory (Pieces, ADRs, agent memory files) stops at code. Belief tracking over time, claim-level provenance and a personal research agent working over your *own* corpus are open gaps.

### Cited Findings
- ADR practice: keep records in the repo (docs/adr/), one decision per record, with a status field (proposed/accepted/deprecated/superseded) and an immutable body where only the status changes. The core value is capturing *why*. The failure mode is losing the rationale when the decider leaves. — [TechTarget](https://techtarget.com/searchapparchitecture/tip/4-best-practices-for-creating-architecture-decision-records); [dev.to, ADRs that get used](https://dev.to/jonoherrington/how-to-write-architecture-decision-records-that-actually-get-used-4i2); [jacob.blog](https://jacob.blog/notes/architecture-decision-records)
- Log4brains-style ADR knowledge bases exist (published "architecture knowledge base" sites). — [AWS ParallelCluster UI log4brains](https://aws.github.io/aws-parallelcluster-ui/log4brains/)
- Pieces' LTM-2 / LTM-2.5 is described as an on-device long-term memory that tags snippets and context so they can be retrieved "weeks or months later." No independent hands-on review of LTM quality was found, and the version number is inconsistent across listings. — [doolpa](https://www.doolpa.com/article/pieces-for-developers); [G2](https://g2.com/products/pieces-for-developers/reviews) (4.5/5, 75 reviews)
- Granola's agent Chat with inline citations across years of notes shows that a "query my own history with citations" agent is now expected in at least one vertical (meetings). — [skillscouter](https://skillscouter.com/granola-review/)
- NotebookLM in mid-2026 added agentic source-finding and code execution, but it is cloud-only and scoped to notebooks, not a lifelong personal corpus. — [WinBuzzer](https://winbuzzer.com/2026/06/09/google-adds-gemini-35-and-antigravity-to-notebooklm-xcxwbn/)
- DEVONthink 4 lets AI run inside smart rules (automated per-item processing), the closest existing primitive to a personal research agent over a local corpus. — [DEVONtechnologies "New in DT4"](https://devontechnologies.com/apps/devonthink/new)

### Inferences
- **Cross-type linking (paper → claim → idea → decision → commit)** is the clearest unique opportunity. No product found spans literature tools, PKM and code memory. A single-owner app can define a fixed edge vocabulary (`supports`, `contradicts`, `inspired`, `implemented-in`, `superseded-by`) across all object types.
- **Belief or claim tracking over time:** ADRs' status lifecycle (proposed, accepted, superseded) is a working model that could generalize to *personal beliefs and research claims*. Each claim gets a confidence and a status history, and when a new paper arrives, the app shows which held claims it touches. No product found offers this; treat it as a design hypothesis, not a validated feature.
- **Provenance:** every AI-generated sentence, summary or tag should carry a pointer to source passages and the model/run that produced it, with versioning (DT4 now auto-versions). This addresses the hallucination complaints directly.
- **Personal research agent:** combine smart-rule-style triggers (DT4) with grounded Q&A (NotebookLM, Granola Chat), running on a local corpus. Example: "when a new PDF lands, find my notes and claims it supports or contradicts, then queue a review card." That pairs the compounding mechanisms from Q1 (proactive See Also plus SRS) with automation.
- **Code knowledge:** mining git history and agent memory files (CLAUDE.md, Cursor rules) into Decision objects linked to the notes and papers that motivated them is unaddressed by any tool found. This is an inference; no sources specifically on CLAUDE.md or Cursor memory practices were retrieved.

### Gaps
- No sources retrieved on Claude Code or Cursor memory-file practices, TIL repos or git-history mining tools. A follow-up search is needed if the final report needs to cite these.
- No found product or paper explicitly implementing personal "belief tracking over time." The absence is notable, but a narrow search may have missed niche tools.
- Recall (getrecall.ai) knowledge-graph and auto-linking features were not researched.

---

## Q4. What makes a tool feel fast and frictionless?

### Takeaway
Little hard data was found within the search budget. The available signals: local-first and offline operation is a selling point (Mem 2.0 relaunched as offline-first, DT4 and Pieces run on-device), lag on large canvases or PDFs is a top complaint (Heptabase), and setup or configuration friction is the top onboarding complaint (Tana). Capture latency, keyboard-first operation and command palettes are widely assumed to matter, but no measured evidence was found.

### Cited Findings
- Mem 2.0's relaunch led with offline-first operation and voice capture. — [AlternativeTo](https://alternativeto.net/news/2025/10/mem-2-0-relaunches-with-smarter-note-taking-tools-offline-support-and-a-new-agentic-chat)
- Heptabase users report lag on large whiteboards and heavy PDF use. — [Product Hunt](https://www.producthunt.com/products/heptabase/reviews)
- Pieces markets on-device processing ("no code uploaded to the cloud unless explicitly saved"). — [doolpa](https://www.doolpa.com/article/pieces-for-developers) (secondary)
- Granola's no-bot, local-audio capture is reviewers' main reason for preferring it, especially in regulated fields. — [skillscouter](https://skillscouter.com/granola-review/)
- Tana's steep configuration curve. — [Tana ideas board](https://ideas.tana.inc/posts/526-quick-select-the-main-tag-or-drag-and-drop-to-switch-supertag-order)

### Inferences
- For a native Mac app, the priorities are a sub-second global capture hotkey with zero required fields (classification deferred to background AI), local storage so search and See Also never wait on the network, and a command palette as the single entry point. These are reasoned design priorities, not evidence-backed.
- Background AI (tagging, linking, summarizing) should never block capture. DT4 smart rules show the asynchronous "process after capture" pattern.

### Gaps
- No primary sources found on capture-latency thresholds, keyboard-first adoption or command-palette usage in PKM tools. Raycast, Drafts, Bear and Things-style capture UX could be researched as positive examples.

---

## Q5. Ranked features to build and anti-features to avoid (synthesis for the report writer)

### Takeaway
Build the compounding loops first: grounded retrieval, proactive related items, SRS on *selected* material, and typed cross-links with provenance. Avoid general-purpose schema builders, infinite canvases as primary storage, passive total-recall lifelogging, cloud-only AI and open-world AI answers presented without passage citations.

### Cited Findings
(The ranking rests on findings cited in Q1–Q4. The key anchors are repeated here.)
- FSRS's benchmark superiority. — [Expertium Benchmark](https://expertium.github.io/Benchmark.html)
- The mnemonic medium's retention gain comes with a 35–50% reading overhead. — [Matuschak](https://notes.andymatuschak.org/Mnemonic_medium)
- An inspector-panel See Also goes underused. — [MacStories](https://www.macstories.net/reviews/ai-adds-a-new-dimension-to-devonthink-4/)
- Canvas sprawl. — [dev.to Heptabase](https://dev.to/pickuma/heptabase-review-visual-note-taking-for-thinking-through-problems-5daa)
- Rewind and Omnivore shutdowns. — [9to5Mac](https://9to5mac.com/2025/12/05/rewind-limitless-meta-acquisition/); [yaps.ai](https://www.yaps.ai/blog/omnivore-alternative.md)
- Collector's fallacy. — [Zettelkasten forum](https://forum.zettelkasten.de/discussion/comment/1067/)
- Elicit's low recall. — [CASRAI](https://casrai.org/compare/elicit-vs-consensus)

### Inferences

**Features worth building (ranked by compounding value against cost)**
1. **Grounded Q&A over your own corpus with passage-level citations** (NotebookLM or Granola Chat pattern, run locally). It turns every past capture into answerable material and is the main defense against hallucination.
2. **Proactive, inline "See Also"** (DEVONthink-style similarity, but pushed into the editor and reader rather than hidden in an inspector) across *all* types: paper ↔ note ↔ code decision.
3. **Typed objects with a small fixed schema** (Paper, Clip, Idea/Note, Claim, Project, Decision, Person) plus **typed cross-links** (`supports`, `contradicts`, `implemented-in`, `superseded-by`). This captures the supertag benefit without Tana's configuration cliff.
4. **Spaced repetition with FSRS for deliberately chosen prompts.** Prompts can be authored or AI-drafted from highlights and accepted by the user. Don't SRS everything; per Matuschak, selective prompting pays for its overhead.
5. **Provenance and versioning on everything**, especially AI output: source passage, model and date, with automatic versions (as in DT4).
6. **Claim and belief ledger with a status lifecycle** (ADR-style: proposed, held, revised, superseded) plus "new source touches held claim" alerts. This is the unique differentiator; no product found does it.
7. **Background research agent with triggers** (DT4 smart-rules style): on ingest, auto-summarize, tag, link, and queue a review or prompt.
8. **Literature-graph expansion from a seed paper** (Litmaps/ResearchRabbit-style chaining) feeding into the local corpus. Integrate rather than rebuild, since that market is consolidating.
9. **Light resurfacing** (Readwise-style daily review) mixed with SRS: cheap to build and habit-forming, though long-term evidence is anecdotal.
10. **Decision capture for code** (ADR objects linked to commits and to the papers or notes that motivated them, importable from repo docs/adr and agent memory files).
11. **Canvas as a *view*** over existing objects for synthesis sessions, not a separate storage silo.

**Anti-features to avoid**
- A general-purpose schema and template builder UI (Tana and Capacities onboarding cliff). Hard-code your own types instead.
- An infinite canvas as the main home for knowledge (sprawl and lag, per the Heptabase reports).
- Passive total-recall screen or audio lifelogging as a core feature (Rewind was killed, and value without curation is unproven). If anything, use Granola-style hybrid capture for meetings only.
- Open-world AI answers without passage citations (Elicit and ChatGPT hallucination and recall problems).
- Cloud-only or proprietary-only storage (Rewind, Omnivore and Pocket shutdowns; Logseq migration risk). Keep an open-format mirror ("file over app").
- Capture with no processing nudge, which leads straight to the collector's fallacy and the note graveyard.
- Related-content features hidden in an opt-in inspector panel (the DT4 underuse signal).
- Graph-view eye candy as a primary navigation tool. The DT4 Graph section was also "not used much" per MacStories; this is a weak signal.

### Gaps
- The ranking is a reasoned synthesis. No source compares these features head-to-head on long-term value.
- Products not covered within budget: Recall, Scholarcy, Semantic Scholar, Connected Papers (2026 status), Reflect, Bear, Craft, Notion AI, Anytype, Napkin, Scrintal, Muse. Their current status (including whether any are defunct) should be checked before the final report names them.
