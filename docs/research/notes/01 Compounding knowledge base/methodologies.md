# Knowledge-management methodologies for a compounding Obsidian knowledge base

Scope: principles and methods, not plugins. Research date 2026-11-03. Source quality: primary sources (Matuschak, Ango, Forte, zettelkasten.de, LYT pages) plus peer-reviewed cognitive science for mechanisms. Practitioner evidence is anecdotal (forums, HN, blogs). **I found no controlled study of any PKM method (Zettelkasten, PARA, LYT, evergreen notes) and its effect on long-term output.** Every claim that these systems "compound" is either self-reported or an argument from mechanism.

---

## Q1. Core principles of each method and the mechanism by which each claims value compounds

### Takeaway
The methods divide into two families.
- **Thinking/writing systems** (Luhmann/Ahrens Zettelkasten, Matuschak evergreen notes, Ango's bottom-up vault, Milo's LYT/MOCs). These claim compounding through accumulating and interlinking ideas written in your own words, so each new note gains value from the existing network.
- **Retrieval/action systems** (Forte's PARA/BASB with progressive summarization, Johnny.Decimal). These claim value from fast retrieval and reuse for current projects, not from idea development.

The 2026 newcomer, Karpathy's "LLM wiki", hands the writing and linking to an LLM. That inverts the mechanism the first family depends on.

### Cited Findings

**Zettelkasten (Luhmann) / Ahrens, *How to Take Smart Notes* (2017)**
- Luhmann kept two boxes of index cards: one of literature notes from sources, one of his own thoughts, with one idea per card. — [Ness Labs summary](https://nesslabs.com/?p=9347); [Ernest Chiang 2025 summary](https://www.ernestchiang.com/en/posts/2025/sonke-ahrens-how-to-take-smart-notes/)
- Ahrens's three note types:
  - **Fleeting notes:** quick captures, discarded once processed.
  - **Literature notes:** short, selective, in your own words, with the source cited.
  - **Permanent notes:** self-contained, standalone ideas, linked to related notes.
  — [Ness Labs](https://nesslabs.com/?p=9347); [Jamworks](https://www.jamworks.com/news/how-to-take-smart-notes-note-taking-techniques-for-success)
- Luhmann's output is commonly cited as the proof of compounding, but the figures vary: "more than 70 books and nearly 400 scholarly articles" in one summary, "over 500 papers and more than 50 books" in another. I could not verify the widely quoted figure of roughly 90,000 cards in the sources I checked. — [search summary of Ahrens reviews](https://www.ernestchiang.com/en/posts/2025/sonke-ahrens-how-to-take-smart-notes/); [GreaterWrong review](https://www.greaterwrong.com/posts/T382CLwAjsy3fmecf/how-to-take-smart-notes-ahrens-2017)
- Ahrens's terminology is inconsistent with Luhmann's practice, and many readers took Ahrens's interpretation for Luhmann's method. Specifically:
  - In Luhmann's usage, "literature notes" were essentially bibliographic cards.
  - Ahrens never names the core note, the Zettel.
  - Permanent notes are not truly immutable.
  — [F. Lengyel, zettelkasten.de guest post, 2022-02-10](https://zettelkasten.de/posts/concepts-sohnke-ahrens-explained/)

**Andy Matuschak, evergreen notes**
- Five principles: evergreen notes should be **atomic**, **concept-oriented**, and **densely linked**. Prefer **associative ontologies to hierarchical taxonomies**. **Write notes for yourself by default.** — [Evergreen notes](https://notes.andymatuschak.org/Evergreen_notes)
- Compounding claim: evergreen notes are meant to "evolve, contribute, and accumulate over time, across projects". He frames the goal as "better thinking", not "better note-taking". "Most people take only transient notes." — [Evergreen notes](https://notes.andymatuschak.org/Evergreen_notes)
- Where he departs from classic Zettelkasten:
  - Titles serve as the index and work like APIs ("Evergreen note titles are like APIs"), instead of numeric IDs.
  - A writing inbox holds transient and incomplete notes, revisited with spaced repetition.
  - Spaced-repetition prompts are embedded in the notes.
  - A daily morning writing practice.
  - Notes serve core creative projects. He observes that many Zettelkasten users mostly write about *others'* ideas.
  — [Similarities and differences between evergreen note-writing and Zettelkasten](https://notes.andymatuschak.org/Similarities_and_differences_between_evergreen_note-writing_and_Zettelkasten)

**Steph Ango (kepano, Obsidian CEO), "How I use Obsidian"**
- The approach is bottom-up, described as one that "embraces chaos and laziness to create emergent structure":
  - Very few folders and no nesting. Most notes sit in the vault root. Folders exist only for references, clippings, attachments, daily notes and templates.
  - Organization comes mainly from a `categories` property, with Bases views over it.
  — [stephango.com/vault](https://stephango.com/vault)
- Linking rules:
  - "Link the first mention of something."
  - Unresolved links are deliberate "breadcrumbs for future connections".
  - Heavy linking lets him trace how ideas emerged and branched over time. This is the page's closest claim to compounding.
  — [stephango.com/vault](https://stephango.com/vault)
- Daily-note and review practice:
  - Daily notes are never written in; they exist only as link targets.
  - Timestamped notes are reviewed every few days, then monthly and yearly, forming a "fractal" review.
  - Every few months he does a "random revisit" to add missing links.
  — [stephango.com/vault](https://stephango.com/vault)
- He refuses to automate the review with LLMs: "Don't delegate understanding." — [stephango.com/vault](https://stephango.com/vault)
- Rules include one vault, no folders for organization, standard Markdown only, and pluralized categories. A consistent style "collapses hundreds of future decisions into one". — [stephango.com/vault](https://stephango.com/vault)

**Nick Milo, Linking Your Thinking (LYT), ACE and Maps of Content (MOCs)**
- ACE has three top-level spaces: **Atlas** for timeless knowledge, **Calendar** for time-based notes, and **Efforts** for work in progress. LYT pitches ACE as more than a folder scheme. — [LYT: ACE folder framework](https://blog.linkingyourthinking.com/notes/ace-folder-framework); [dsebastien notes](https://notes.dsebastien.net/30+Areas/32+Literature+notes/32.02+Content/ACE+Framework)
- The "mental squeeze point" is the moment when the volume of unsorted notes starts to overwhelm you. The remedy is to create an MOC at that point. MOCs are the bottom-up response, used to make sense of notes that already exist; they are not a top-down taxonomy imposed in advance. — [LYT glossary](https://blog.linkingyourthinking.com/notes/lyt-glossary); [MOCs overview](https://blog.linkingyourthinking.com/notes/mocs-overview)
- A forum post says Milo uses MOCs as a working space for arranging thoughts, not as a plain index. — [Obsidian forum](https://forum.obsidian.md/t/outlining-for-academic-work-moving-notes-around/13760/2)

**Tiago Forte, PARA and Building a Second Brain**
- PARA has four buckets:
  - **Projects:** short-term, with a goal and an end.
  - **Areas:** ongoing responsibilities.
  - **Resources:** topics of interest.
  - **Archives:** inactive items.
  Forte organizes by **actionability**, "according to the projects and goals you are committed to right now". He explicitly argues against broad subject folders like "Psychology" as the primary structure. — [Forte Labs: PARA](https://fortelabs.com/blog/para/)
- **Progressive summarization** (2017, updated 2023) works in layers:
  - Layer 0: the source.
  - Layer 1: captured passages.
  - Layer 2: bolded passages.
  - Layer 3: highlights within the bold.
  - Layer 4: an executive summary in your own words.
  - Remix: turn the material into new work.
  Layers are added opportunistically, only when you touch a note again ("spending attention twice"). Notes are designed for an impatient "Future You", balancing compression against context. — [Forte Labs: Progressive Summarization](https://fortelabs.com/blog/progressive-summarization-a-practical-technique-for-designing-discoverable-notes/)

**Johnny.Decimal**
- Structure: up to 10 areas, each with up to 10 categories, and IDs like `12.03`. Everything is at most two levels deep. — [johnnydecimal.com: areas & categories](https://johnnydecimal.com/concepts/areas-categories/)
- Compared with PARA: Johnny.Decimal sorts by stable *type*, so items stay put. PARA sorts by *state*, so items move between buckets. Some users combine the two, with PARA on top and Johnny.Decimal numbering beneath. Third-party commentators argue that Obsidian's strength is linking, not deep folder schemes. — [dsebastien: Johnny Decimal](https://dsebastien.net/blog/2022-04-29-johnny-decimal); [ai-wiki-pkm](https://ai-wiki-pkm.pages.dev/johnny-decimal-system)

**Newer (2025–2026): Karpathy's "LLM wiki" / LLM knowledge bases**
- The pattern, made public in April 2026 (sources disagree between 3 and 11 April):
  - Drop sources into a `raw/` folder.
  - An LLM "compiles" them into an interlinked markdown wiki and handles nearly all writing and maintenance.
  - Obsidian serves as the viewing front end.
  - Filing the answers to queries back into the wiki is described as the flywheel.
  - Community Obsidian plugins (KarMind and others) appeared soon after.
  — [MindStudio write-up](https://www.mindstudio.ai/blog/andrej-karpathy-llm-wiki-obsidian-ai-second-brain); [Daniel Vaughan, 2026-04-11](https://codex.danielvaughan.com/2026/04/11/karpathy-llm-knowledge-bases-codex-resources-flywheel/); [KarMind plugin](https://community.obsidian.md/plugins/karmind)
  - Caveat: these are secondary write-ups. I did not verify Karpathy's original post.

### Inferences
- The methods disagree about *who does the processing* and *why*.
  - Zettelkasten, Matuschak and Ango locate compounding in the act of the human rewriting and linking ideas: the note is a by-product of thinking.
  - PARA and Johnny.Decimal locate value in retrieval and reuse for current projects.
  - The LLM-wiki pattern keeps the network-of-linked-notes artifact but removes the human generation step. On the cognitive-science evidence in Q5, that likely forfeits the learning benefit while keeping the reference benefit. This is an inference; no study has tested it.
- Matuschak and Ango both make a revisiting loop part of the method itself: spaced repetition for Matuschak, fractal and random review for Ango. Ahrens's and Forte's popular summaries put less weight on this. It may be an under-appreciated driver of compounding (see Q5, retrieval practice).

### Gaps
- I did not verify a primary Forte source on CODE (Capture, Organize, Distill, Express) or on "intermediate packets". These are known from *Building a Second Brain* (2022) but were not fetched this session. The PARA article itself does not explain how value compounds.
- I found no canonical Milo document stating the ACE mechanism, only LYT blog and glossary pages.
- I could not confirm the commonly cited figure of about 90,000 Luhmann cards.

---

## Q2. What evidence and long-term (5+ year) practitioner experience say actually works, versus collector's fallacy and productivity-porn failure modes

### Takeaway
No rigorous evidence exists. Long-term accounts converge on two points.
- **What works:** writing in your own words about ideas you are actively using, plus linking. Payoff is slow and is reported mostly by people who write for output (researchers, essayists).
- **The dominant failure mode:** accumulation without processing. This is the collector's fallacy: an archive that becomes a "mausoleum", maintenance pushed to a future self, and filing that substitutes for thinking.

### Cited Findings
- **Collector's fallacy** (Christian Tietze, zettelkasten.de, 2014-01-20):
  - "Knowing *about* something" is not knowing it.
  - Collecting is self-rewarding, much like conditioning. Umberto Eco warned that photocopies give an illusion of having read the text.
  - Remedies: take notes while reading; shorten the research-read-assimilate cycle; use time-boxes and feedback.
  — [zettelkasten.de: The Collector's Fallacy](https://zettelkasten.de/posts/collectors-fallacy/)
- **Joan Westenberg, "I deleted my second brain"** (2025-06-16): she deleted about 10,000 Obsidian notes and Apple Notes dating back to 2015.
  - **Diagnosis:**
    - Accumulation treated as a virtue.
    - An archive that became a "mausoleum".
    - Deferral of sorting, tagging and distilling to a future self who never arrived.
    - Filing that felt like understanding: she read in order to extract, not to think.
  - **Wider critique:** the "second brain" metaphor misrepresents associative memory, and PKM can become "productivity theater".
  - **Plan:** rebuild Obsidian later "as a workspace", not a storehouse.
  - Quote: "I don't want to manage knowledge. I want to live it."
  — [Westenberg](https://westenberg.beehiiv.com/p/i-deleted-my-second-brain)
  - Response: a DEVONthink user moved all Markdown out of Obsidian and did not miss it. — [DEVONthink forum](https://discourse.devontechnologies.com/t/devonthink-obsidian/73208/96)
- **Hacker News and forum skeptics:**
  - Zettelkasten is "a much slower note-taking process" and makes sense mainly for prolific writers.
  - One commenter recalled an academic for whom it took about 8 years before it paid off.
  - Another found it "too much work for very little gain".
  - A zettelkasten.de forum member saw no productivity gains after about 10 months of daily work.
  — [HN thread](https://news.ycombinator.com/item?id=22492381); [HN mirror](https://nextjs-hackernews.vercel.app/item/47700556); [Zettelkasten forum](https://forum.zettelkasten.de/discussion/comment/10531/) (aggregated via search; individual comments not fully verified)
- **Positive self-reports:**
  - Abram Demski (LessWrong, 2019) estimates Zettelkasten gave him "at least 2x" research productivity. — [LessWrong](https://www.lesswrong.com/posts/NfdHG6oHBJ8Qxc26s/the-zettelkasten-method-1)
  - A two-year OneNote practitioner says the value is mainly in linking, for deep, lasting learning. — [Everything OneNote](https://everythingonenote.substack.com/p/two-years-using-the-zettelkasten)
  - An academic Obsidian user since 2022 credits the system with a productive period (just over 50,000 words written in 2025). — [lateworld substack, via search](https://lateworld.substack.com/p/failing-upward)
- **"Do links really surface surprising connections?"** On the Obsidian forum, a user with 3 years and 9,000 cards had forgotten notes entirely and asked how to make connections emerge. — [Obsidian forum](https://forum.obsidian.md/t/zettelkasten-linking-for-surprising-connections/33214)
- **Hub-note overhead:** a Substack writer found hub notes "hard to manage and keep updated pretty quickly". — [pjordan substack](https://pjordan.substack.com/p/obsidian-zettelkasten-and-the-holy)
- **Large-vault veterans** (Obsidian forum thread, 6k–15k notes, 4–5+ years):
  - **harr** (10K+ notes, 4+ years): the vault "got out of hand" only when it was small (under 1,000 notes); larger vaults became easier. Advice: embrace messiness and use links, tags, properties and folders together. Under 100 notes, no system is needed.
  - **EggToastie** (6,978 notes, 5 years): moved most documents *out* of the vault and kept only evergreen notes inside.
  - **CawlinTeffid:** restructuring is inevitable. Let old conventions persist in old notes and update them only when touched.
  - **I-d-as:** organizing creative ideas early creates "knots". Capture first and organize when ready.
  - **Edmund** (~6,500 notes): cites "tagging without organization" as a Zettelkasten "deadly sin".
  — [Obsidian forum: huge vaults](https://forum.obsidian.md/t/for-those-with-huge-vaults-anything-you-d-do-differently-or-wish-you-d-known-before-starting/99754)

### Inferences
- The reported successes (Luhmann, Demski, the academic writer, Matuschak) share a **production target**: papers, books, essays, research. The reported failures (Westenberg, the HN skeptics) describe capture and storage *without* a regular output that pulls notes through processing. The compounding variable looks less like "which method" and more like "is there a writing or output loop consuming the notes".
- Payoff is back-loaded. Practitioners report years before the network is dense enough to surprise them. Advice to "start small, don't design up front" fits this: early structure is premature (the "knots" problem) and the vault only becomes navigable at scale.
- "Productivity porn" overhead clusters in:
  - elaborate up-front taxonomies, such as deep folder trees or heavily designed Johnny.Decimal schemes for idea notes;
  - hub notes maintained by hand;
  - tag proliferation;
  - importing whole libraries into the vault;
  - deferred processing queues.

### Gaps
- No longitudinal or controlled study compares Zettelkasten, PARA or LYT users on output or learning. All evidence here is self-report with heavy survivorship bias: people who quit rarely write 5-year retrospectives, except dramatic exits like Westenberg's.
- I did not retrieve a substantive r/ObsidianMD or r/Zettelkasten "N years" thread; the coverage is from the Obsidian forum, HN and blogs.

---

## Q3. The role of literature, permanent and fleeting notes, and how much processing is worth it

### Takeaway
Every thinking-oriented method agrees that **the step that matters is rewriting an idea in your own words as a self-contained note and connecting it to what you already have**. Fleeting notes are disposable scaffolding. Literature notes should be brief and selective. Forte's alternative is layered highlighting, done just-in-time. It is cheaper, but the cognitive-science evidence on highlighting is weak (see Q5); only its Layer 4 (a summary in your own words) resembles the generative step.

### Cited Findings
- **Ahrens's pipeline:**
  - Fleeting notes are disposable once processed.
  - Literature notes are short, selective, in your own words, and cited.
  - Permanent notes are written to stand alone and are linked into the slip-box.
  — [Ness Labs](https://nesslabs.com/?p=9347); [Jamworks](https://help.jamworks.com/en/articles/6840216-how-to-take-smart-notes)
- **Lengyel's view of what is essential:**
  - Capture by hand while reading and recast quickly, within a day or two.
  - Rewrite permanent notes in your own words "as if for print".
  - Keep them self-contained.
  - Literature notes can live in a reference manager.
  - Luhmann's literature notes were brief; the care went into the Zettel.
  — [zettelkasten.de, 2022](https://zettelkasten.de/posts/concepts-sohnke-ahrens-explained/)
- **Matuschak:**
  - "Write about what you read to internalize texts deeply."
  - Even when describing others' ideas, rewrite them in your own words.
  - Uses a reading inbox for possibly-useful references and a writing inbox for transient notes.
  — [Evergreen notes](https://notes.andymatuschak.org/Evergreen_notes); [Similarities and differences](https://notes.andymatuschak.org/Similarities_and_differences_between_evergreen_note-writing_and_Zettelkasten)
- **Forte:**
  - Process opportunistically, only when you are already touching a note for a project.
  - Summarize only as much as the material deserves.
  - Keep earlier layers as a safety net, because summarizing is risky.
  - Over-compression destroys context.
  — [Forte Labs: Progressive Summarization](https://fortelabs.com/blog/progressive-summarization-a-practical-technique-for-designing-discoverable-notes/)
- **Ango:**
  - Clippings and references go in separate folders, apart from his own notes.
  - His own timestamped notes are reviewed in a fractal cadence.
  - He will not delegate review to LLMs.
  — [stephango.com/vault](https://stephango.com/vault)
- **Collector's fallacy remedy:** process soon after collecting, in short loops. — [zettelkasten.de](https://zettelkasten.de/posts/collectors-fallacy/)

### Inferences
- How much processing is worth it, by note type:
  - **Fleeting notes:** process within days or delete. Untouched inboxes are the failure mode named in both Westenberg and the collector's fallacy.
  - **Literature notes:** keep them minimal (citation plus a few key points in your own words), not exhaustive highlight dumps.
  - **Permanent or evergreen notes:** write them only for ideas you would actually use or argue with. That is where the effort earns its keep.
  - **Bulk reference material** (PDFs, clippings, imported libraries): keep it outside the idea network, in a separate folder or out of the vault. EggToastie's and randomjoe's experience supports this.
- Forte's "process when touched" rule and the Zettelkasten "process now" rule can be reconciled. Process immediately when the idea is live; otherwise leave the raw capture and let use trigger refinement. The non-negotiable step is the final rewrite in your own words.

### Gaps
- No empirical data on the optimal processing ratio (for example, the share of highlights that should become permanent notes). Figures in circulation are folk heuristics.

---

## Q4. Where the methods agree and conflict, and the hybrid experienced users converge on

### Takeaway
The main conflict is **top-down containers (PARA, Johnny.Decimal, ACE folders) versus bottom-up emergent structure (links, MOCs created at the squeeze point, Ango's categories property)**. Experienced Obsidian users converge on a hybrid:
- **Minimal folders**, used for note *type* or lifecycle (sources/clippings, attachments, templates, daily, maybe active projects), not for topics.
- **Flat idea notes**, connected by links and properties.
- **MOCs created only when a cluster becomes unwieldy.**
- **Light, actionability-based project spaces** (the useful part of PARA).
- A **regular review loop.**

### Cited Findings
- **Points of agreement:**
  - Atomicity, concept orientation, dense linking and your own words are shared by Zettelkasten and evergreen notes. — [Matuschak](https://notes.andymatuschak.org/Similarities_and_differences_between_evergreen_note-writing_and_Zettelkasten)
  - Associative over hierarchical. — [Matuschak](https://notes.andymatuschak.org/Evergreen_notes)
  - Ango avoids folders for organization and favors links and properties. — [stephango.com/vault](https://stephango.com/vault)
  - Milo's MOCs are explicitly bottom-up, created at the squeeze point. — [LYT MOCs overview](https://blog.linkingyourthinking.com/notes/mocs-overview)
- **Points of conflict:**
  - PARA organizes by actionability, with items moving between buckets. — [Forte](https://fortelabs.com/blog/para/)
  - Johnny.Decimal organizes by stable categories in a fixed two-level tree. — [johnnydecimal.com](https://johnnydecimal.com/concepts/areas-categories/)
  - Both are container-first, which contrasts with link-first methods. A commentator argues Obsidian's strength is linking, not folder hierarchy. — [ai-wiki-pkm](https://ai-wiki-pkm.pages.dev/johnny-decimal-system)
  - Classic Zettelkasten uses numeric IDs and sequence (Folgezettel). Matuschak uses titles as API-like handles. — [Matuschak](https://notes.andymatuschak.org/Similarities_and_differences_between_evergreen_note-writing_and_Zettelkasten)
- **Convergence in practice:**
  - A historian on the Obsidian forum uses folders only to separate note types that need different templates (people, places), links for navigation, and subject MOCs fed by atomic notes. — [Obsidian forum: historians](https://forum.obsidian.md/t/obsidian-for-historians/80568)
  - "Use one folder for basically everything" (RyzenFromFire, ~8k files), navigating by Quick Switcher, links and MOCs. Another user found tags and metadata easier to restructure than folders. — [Obsidian forum: huge vaults](https://forum.obsidian.md/t/for-those-with-huge-vaults-anything-you-d-do-differently-or-wish-you-d-known-before-starting/99754)
  - Another user builds MOCs from tags for convenience rather than hand-maintained links. — [Obsidian forum: opinionated reflection](https://forum.obsidian.md/t/an-opinionated-reflection-on-using-folders-links-tags-and-properties/78548)
  - A folder-free account relies on backlinks, graph and MOCs, plus one "System" folder for attachments and templates. — [MakeUseOf](https://www.makeuseof.com/obsidian-vault-organization-without-folders/)
  - Hybrid PARA on top with Johnny.Decimal numbering beneath, or Johnny.Decimal-numbered top folders with wikilinks inside. — [dsebastien](https://dsebastien.net/blog/2022-04-29-johnny-decimal); [ai-wiki-pkm](https://ai-wiki-pkm.pages.dev/johnny-decimal-system)
  - Ango, as Obsidian CEO, practices a near-flat vault organized by a `categories` property and Bases views. — [stephango.com/vault](https://stephango.com/vault)

### Inferences
- In practice, PARA and Johnny.Decimal work best for *actionable and administrative material* (projects, documents, life admin). Link-first methods work best for *ideas*. The two can coexist: PARA-like project and area containers hold work in flight, and a flat, linked idea layer accumulates across projects. ACE is essentially this split (Efforts versus Atlas, plus Calendar).
- Properties and Bases, as Ango uses them, are the 2024–2026 replacement for folder taxonomies: queryable, multi-membership categorization without the "which folder?" decision. Advice from before about 2024 that leans on deep folders or heavy tag hierarchies is somewhat dated for Obsidian.
- **Outdated or contested advice to flag:**
  - **Rigid Folgezettel numbering in a digital vault.** Matuschak and most Obsidian users use titles and links instead.
  - **Hand-maintained hub notes everywhere.** These are maintenance-heavy (pjordan); create them at the squeeze point only.
  - **Highlight-centric progressive summarization as a learning method.** The evidence is weak (Q5); it is fine for retrieval design.
  - **"Second brain" as an external memory store.** Critiqued by Westenberg and others. Ango and Matuschak frame the vault as a thinking workspace instead.

### Gaps
- No survey data on what share of long-term Obsidian users end up on which hybrid. Convergence here rests on qualitative forum and blog patterns.

---

## Q5. Cognitive-science backing for these practices (generation effect, elaboration, spaced retrieval, desirable difficulties)

### Takeaway
The practices that thinking-oriented methods insist on have real but modest support:
- **Writing in your own words** (generation effect, generative learning)
- **Connecting to prior knowledge** (elaboration, integration)
- **Revisiting** (spacing, retrieval practice)

Forte's highlighting layers are rated **low utility** for learning. The popular "longhand forces paraphrase" story behind note-taking advice did *not* replicate cleanly.

### Cited Findings
- **Generation effect.** Bertsch, Pesta, Wiscott and McDaniel (2007), *Memory & Cognition* 35(2): a meta-analysis of 445 effect sizes from 86 studies. Generated items were remembered about 9% better than read items, an effect of roughly d = 0.40. Generation *difficulty* did not predict memory. The data are mostly word-list paradigms, not text or notes. — [PubMed 17645161](https://pubmed.ncbi.nlm.nih.gov/17645161/); [PDF](https://mcdaniel97.github.io/Publications/Bertsch%20et%20al.%202007.pdf)
- **Generative learning.** Fiorella and Mayer (2016, *Educational Psychology Review*) list eight strategies: summarizing, mapping, drawing, imagining, self-testing, self-explaining, teaching, and enacting. Generative learning means actively reorganizing new information and integrating it with prior knowledge (Wittrock's generative model; Mayer's select-organize-integrate framework). — [Eight Ways to Promote Generative Learning (summary)](https://www.umpi.edu/ctl/?p=5173)
- **Ratings of learning techniques.** Dunlosky et al. (2013, *Psychological Science in the Public Interest*):
  - **Practice testing** and **distributed practice** rated **high utility**.
  - **Summarization, highlighting, rereading, keyword mnemonic and imagery for text** rated **low utility**.
  - Summarization "helps some students on some tasks" under unclear conditions.
  - Highlighting and rereading do not reliably improve performance.
  — [APS press release](https://www.psychologicalscience.org/news/releases/which-study-strategies-make-the-grade.html); [Stafforini](https://stafforini.com/works/dunlosky-2013-improving-students-learning/)
- **Longhand versus laptop.** The Mueller and Oppenheimer (2014) claim that longhand notes improve learning through paraphrase was not supported:
  - Morehead, Dunlosky and Rawson (2019) called the case for longhand superiority "premature". — [Educational Psychology Review PDF](https://springerlink.bibliotecabuap.elogim.com/content/pdf/10.1007/s10648-019-09468-2.pdf)
  - Urry et al. (2021, *Psychological Science*) ran a direct replication plus a meta-analysis of 8 studies and found no longhand advantage for immediate learning. Laptop users did take more verbatim notes; the link between verbatim overlap and worse quiz scores was "not robust". — [PubMed 33539228](https://www.pubmed.gov/33539228/); [APS](https://www.psychologicalscience.org/journals/psychological-science/0956797620965541/)
- **Practitioner application.** Matuschak embeds spaced-repetition prompts in his notes and revisits writing-inbox items with spaced repetition. Ango runs scheduled reviews plus a periodic random revisit. — [Matuschak](https://notes.andymatuschak.org/Similarities_and_differences_between_evergreen_note-writing_and_Zettelkasten); [stephango.com/vault](https://stephango.com/vault)

### Inferences
- **Mapping principles to evidence:**

| Principle | Evidence |
|---|---|
| Write in your own words, as a self-contained permanent note | Supported: generation effect, generative summarizing and self-explaining |
| Link a new note to existing notes, with an explanation of *why* | Supported: elaboration, integration with prior knowledge (Fiorella and Mayer's core definition) |
| Revisit and review notes (Ango's fractal review, Matuschak's spaced inbox, random revisit) | Supported: distributed practice. If review means recalling before rereading, also retrieval practice, both rated high utility |
| Progressive summarization Layers 1–3 (highlight, bold) | Weak for learning: Dunlosky rates highlighting low. It may still help *retrieval* by your future self, a different goal |
| Layer 4 executive summary in your own words | Mixed: summarization is low or variable utility in Dunlosky, but generative in Fiorella and Mayer, and quality-dependent |
| Atomicity and concept-oriented titles | No direct cognitive evidence. Plausibly forces a precise claim (a form of generation) and aids later retrieval and recombination. These are design arguments, not tested effects |

- The common claim that "handwriting forces you to paraphrase, so it is better" should be flagged as outdated or unsupported, given the 2019–2021 replications.
- LLM-written notes (the Karpathy LLM-wiki pattern, AI auto-summaries) remove the generation and elaboration steps. Ango's "Don't delegate understanding" names exactly this. A defensible hybrid: let the LLM handle retrieval, linking suggestions and source digests, while the human writes the claims. This is an inference from mechanism; it has not been tested.

### Gaps
- No study tests Zettelkasten-style permanent-note writing against other study or writing methods on long-term outcomes such as idea generation or publication output.
- Effect sizes come from lab paradigms (word lists, short texts, immediate tests). How well they transfer to multi-year personal knowledge bases is unknown.
- I did not retrieve Schindler and Richter (2023) or McCurdy et al. (2020) effect sizes for text-level generation. — [McCurdy et al. 2020](https://link.springer.com/10.3758/s13423-020-01762-3)
