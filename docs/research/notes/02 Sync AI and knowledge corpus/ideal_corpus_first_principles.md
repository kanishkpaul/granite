# The Ideal Intelligent Personal Knowledge Corpus: First Principles (as of Nov 2026)

Scope note for the report writer: this is a requirements-level analysis, not a tool roundup. Sources marked **[verified this session]** were fetched or confirmed via search on 2026-11-03. Sources marked **[canonical]** are well-known primary works cited from the researcher's background knowledge with their standard URLs/DOIs; they were not re-fetched here, and only their widely documented core claims are used. Evidence and speculation are separated: "Cited Findings" = evidence or attributed opinion; "Inferences" = this researcher's reasoning.

---

## 1. Jobs-to-be-done: which matter most, and how are they measured?

### Takeaway
Seven jobs are real, but they are not equal. The evidence base is strongest for **re-finding/recall** (a measured, high-frequency behavior) and **learning via retrieval practice** (one of the most robust findings in cognitive psychology). **Synthesis, reasoning-partner, and output** are the jobs people *want* most from AI and are where AI adds the most new capability, but they are the least measured and carry the highest risk of degrading the user's own understanding. **Self-knowledge (belief change over time)** is the most underserved job and the one that uniquely requires a *personal, temporal* corpus rather than world knowledge.

### Cited Findings
**Recall / re-finding (find what I know)**
- As many as 40% of web queries in a one-year Yahoo log of 114 users were re-finding queries (approximated by repeat clicks on the same result for the same user at different times); changes to previously viewed result lists hampered re-finding — [Teevan, Adar, Jones, Potts, SIGIR 2007](https://people.csail.mit.edu/teevan/work/publications/papers/sigir07.pdf) **[verified this session]**; [MSR page](https://www.microsoft.com/en-us/research/publication/information-re-retrieval-repeat-queries-yahoos-logs/)
- PIM research frames the core activities as *keeping* (deciding what to save and how), *re-finding*, and *meta-level* activities (organizing, maintaining) — William Jones, *Keeping Found Things Found: The Study and Practice of Personal Information Management* (2007) — [Elsevier/Morgan Kaufmann](https://www.sciencedirect.com/book/9780123708663/keeping-found-things-found) **[canonical]**
- Desktop file organization serves two functions: *finding* and *reminding*; users relied heavily on location-based (navigational) finding and used visible placement as a reminder — Barreau & Nardi, "Finding and Reminding: File Organization from the Desktop," SIGCHI Bulletin 1995 — [ACM DL](https://dl.acm.org/doi/10.1145/221296.221307) **[canonical]**
- In personal collections, users prefer navigation over search, using search mainly as a last resort, even when search tools improve — Bergman, Beyth-Marom, Nachmias, Gradovitch, Whittaker, "Improved search engines and navigation preference in personal information management," ACM TOIS 2008 — [ACM DL](https://dl.acm.org/doi/10.1145/1402256.1402259) **[canonical]**
- Reason this matters for AI: personal re-finding relies on *episodic* cues (where/when/with whom I saw it), not just semantic similarity; Teevan's own finding that changed results hamper re-finding implies stability of location/ID is itself a requirement — [Teevan et al. 2007](https://people.csail.mit.edu/teevan/work/publications/papers/sigir07.pdf) **[verified]**

**Learning / retention**
- Retrieval practice (testing) produces substantially better delayed retention than repeated study, even though restudy feels more effective — Roediger & Karpicke, "Test-Enhanced Learning," Psychological Science 2006 — [DOI 10.1111/j.1467-9280.2006.01693.x](https://doi.org/10.1111/j.1467-9280.2006.01693.x) **[canonical]**
- "Desirable difficulties" (spacing, interleaving, generation, testing) slow apparent performance during learning but improve long-term retention and transfer — Robert Bjork (1994) and Bjork & Bjork (2011) — [Bjork Learning & Forgetting Lab](https://bjorklab.psych.ucla.edu/research/) **[canonical]**
- Generation effect: information people generate themselves is remembered better than information they read — Slamecka & Graf 1978, JEP: Human Learning and Memory — [DOI 10.1037/0278-7393.4.6.592](https://doi.org/10.1037/0278-7393.4.6.592) **[canonical]**
- Mnemonic medium (Quantum Country): ~112 spaced-repetition questions embedded in an essay; after six reviews users averaged ~54 days of demonstrated retention per question for ~95 minutes total review time; authors call results early/preliminary and retracted one claim (trivial early questions improving attention) due to an analysis error — [Matuschak & Nielsen, "How can we develop transformative tools for thought?" (2019)](https://numinous.productions/ttft/) **[verified this session]**

**Synthesis / output / reasoning partner**
- Luhmann described his Zettelkasten as a *communication partner* capable of surprising him — Niklas Luhmann, "Kommunikation mit Zettelkästen" (1981) — [Niklas Luhmann-Archiv](https://niklas-luhmann-archiv.de/) **[canonical]** (i.e., the "reasoning partner" job predates AI).
- Matuschak's "evergreen notes" are explicitly a thinking (not capture) practice: atomic, concept-oriented, densely linked notes so that "insight accumulates" across projects — [notes.andymatuschak.org: "Evergreen note-writing helps insight accumulate"](https://notes.andymatuschak.org/Evergreen_note-writing_helps_insight_accumulate) **[verified via search]**
- Maggie Appleton argues LLMs are best used as "epistemic rubber ducks" — reflective thinking partners that prompt metacognition, not sources of truth or producers of final output — [Appleton, "Language Models as Epistemic Rubber Ducks"](https://maggieappleton.com/epistemic-ducks) **[verified via search]**
- Interviewed philosophers did not find LMs to be good critical-thinking tools; paper proposes three roles — Interlocutor, Monitor, Respondent — [Ye, Moore, Novick, Zhang, arXiv 2404.04516 (2024)](https://arxiv.org/abs/2404.04516) **[verified via search]**

**Self-knowledge / belief change**
- Hindsight bias: people misremember their prior predictions/beliefs as closer to the outcome ("knew it all along") — Fischhoff 1975, JEP: Human Perception and Performance — [DOI 10.1037/0096-1523.1.3.288](https://doi.org/10.1037/0096-1523.1.3.288) **[canonical]**. Implication: only a timestamped external record can reliably show the user how their beliefs changed.

**Measurement benchmarks that exist (for the AI side)**
- LongMemEval evaluates long-term chat-assistant memory on five abilities: information extraction, multi-session reasoning, temporal reasoning, knowledge updates, and abstention — [Wu et al., arXiv 2410.10813 (2024)](https://arxiv.org/abs/2410.10813) **[canonical]**; Zep reports results on it and on Deep Memory Retrieval (Zep 94.8% vs MemGPT 93.4% on DMR, per a talk page) — [Zep paper arXiv 2501.13956](https://arxiv.org/abs/2501.13956); [KGC talk page](https://watch.knowledgegraph.tech/videos/zep-a-temporal-knowledge-graph-architecture-for-agent-memory-720p) **[verified via search]**
- Citation quality: ALCE benchmark found LLM answers frequently lack complete citation support — [Gao et al., "Enabling LLMs to Generate Text with Citations," arXiv 2305.14627 (2023)](https://arxiv.org/abs/2305.14627) **[canonical]**

### Inferences
- **Proposed priority ordering (from first principles):** (1) Trustworthy recall with provenance — everything else depends on it; (2) Output/decision support — the reason most people keep a corpus at all; (3) Synthesis across time — the highest-leverage *new* AI capability; (4) Resurfacing — high value but easy to make annoying; (5) Reasoning partner; (6) Self-knowledge — rare but uniquely personal; (7) Learning/retention — essential for a minority (students, researchers learning a field), optional for others. Learning is the job where AI must *withhold* help.
- **Proposed metrics per job (no standard exists; these are design proposals):**
  - Recall: re-find success rate and time-to-refind on the user's own past queries; *abstention correctness* ("I have no note on that") — borrows LongMemEval's abstention ability.
  - Resurfacing: acceptance rate of resurfaced items (opened/acted on vs. dismissed), with a fatigue budget.
  - Synthesis: fraction of AI-proposed connections the user accepts and later re-uses/links; citation precision (every synthesized claim resolves to a source span).
  - Reasoning partner: number of user-authored revisions/counter-arguments produced per session (an *engagement* metric, not satisfaction).
  - Learning: delayed recall on retrieval-practice prompts (the Quantum Country "demonstrated retention" metric).
  - Output: time-to-draft *plus* user's self-rated ownership and ability to explain the output without the tool (the ownership/recall measures in Kosmyna et al. — see §4).
  - Self-knowledge: ability to answer "what did I believe about X in <date>, and why did it change?" with dated evidence.
- The jobs conflict: maximal output efficiency (AI drafts) undermines learning and ownership (generation effect, §4). The system therefore needs **per-job modes** with different levels of AI assistance rather than one "assistant."

### Gaps
- No found study measures end-to-end usefulness of a personal knowledge base (PKM) over years; PKM evidence is mostly self-report and practitioner essays.
- No reliable evidence found on optimal *resurfacing* (e.g., Readwise-style daily review) for non-flashcard notes; whether random/spaced resurfacing of notes improves synthesis is untested as far as found.

---

## 2. Required properties

### Takeaway
The non-negotiable properties are: **provenance at the claim level** (mine / sourced / AI-generated / AI-proposed-and-accepted), **temporality** (when a claim was believed and when it was recorded — bi-temporal), **verifiability** (every AI statement resolves to a span in a source), **file-over-app longevity and local-first control**, **low capture friction with tolerance for mess**, and **preserved human authorship** of the parts that encode understanding. Epistemic status/confidence is desirable but should be lightweight and optional, since humans won't maintain fine-grained confidence scores.

### Cited Findings
- **Local-first ideals (Ink & Switch, 2019):** seven ideals — fast ("no spinners"), multi-device, works offline ("network optional"), seamless collaboration, longevity ("the Long Now"), security and privacy by default, user retains ultimate ownership and control — [Kleppmann, Wiggins, van Hardenberg, McGranaghan, "Local-first software: You own your data, in spite of the cloud," Onward! 2019](https://www.inkandswitch.com/local-first/) **[canonical]**
- **File over app:** Obsidian CEO Steph Ango argues durable digital artifacts should be files in open formats you control, because apps are ephemeral — [stephango.com/file-over-app (2023)](https://stephango.com/file-over-app) **[canonical]**
- **Provenance modeling standard:** W3C PROV defines entities, activities, and agents (wasGeneratedBy, wasDerivedFrom, wasAttributedTo), a ready vocabulary for "who/what produced this claim from what" — [W3C PROV Overview](https://www.w3.org/TR/prov-overview/) **[canonical]**
- **Temporality / bi-temporal facts:** Zep/Graphiti tracks two timelines — when an event/fact held in the world and when the data was ingested — and invalidates edges rather than deleting them, preserving history while keeping current facts accurate — [Rasmussen et al., arXiv 2501.13956 (Jan 2025)](https://arxiv.org/abs/2501.13956); [ar5iv HTML](https://ar5iv.labs.arxiv.org/html/2501.13956) **[verified via search]**
- **Claim-level representations exist in scholarly communication:** micropublications model claims, evidence, and arguments — [Clark, Ciccarese, Goble, "Micropublications," J. Biomedical Semantics 2014](https://jbiomedsem.biomedcentral.com/articles/10.1186/2041-1480-5-28) **[canonical]**; Joel Chan's "discourse graphs" model Questions, Claims, Evidence as typed note units in Roam/Obsidian — [discoursegraphs.com](https://discoursegraphs.com/) **[canonical]**
- **Atomic propositions improve retrieval:** using propositions (atomic, self-contained factoids) as retrieval units outperformed passage/sentence units in dense retrieval — [Chen et al., "Dense X Retrieval," arXiv 2312.06648](https://arxiv.org/abs/2312.06648) **[canonical]**; FActScore decomposes generations into atomic facts to measure factual precision — [Min et al., arXiv 2305.14251](https://arxiv.org/abs/2305.14251) **[canonical]**
- **Capture vs. hoarding:** the "Collector's Fallacy" — saving material creates a feeling of knowing without processing it — [Christian Tietze, zettelkasten.de (2014)](https://zettelkasten.de/posts/collectors-fallacy/) **[canonical]**; PIM research documents that people keep far more than they re-use and that curation is a burden — [Whittaker, "Personal information management: From information consumption to curation," ARIST 2011](https://doi.org/10.1002/aris.2011.1440450108) **[canonical]**
- **Authorship → memory:** generation effect [Slamecka & Graf 1978](https://doi.org/10.1037/0278-7393.4.6.592) **[canonical]**; LLM-assisted essay writers reported lower ownership and had difficulty quoting their own essays minutes later — [Kosmyna et al., "Your Brain on ChatGPT," arXiv 2506.08872 (2025)](https://arxiv.org/abs/2506.08872) (coverage: [LIRNEasia journal club](https://lirneasia.net/2025/12/lirneasia-journal-club-your-brain-on-chatgpt-exploring-the-cognitive-debt-of-ai-assisted-writing)) **[verified via search]**
- **Trust as a precondition for offloading:** the "Google effect" (remembering where, not what) replicated only when participants had a practice phase demonstrating that saving was reliable — perceived reliability of the store governs offloading — [Memory, 2021 (Taylor & Francis)](https://informahealthcare.com/doi/full/10.1080/09658211.2021.1962356) **[verified via search]**
- **Extended-mind criteria** (Clark & Chalmers' Otto notebook): a resource counts as part of cognition when it is reliably available, easily accessed, automatically endorsed on retrieval, and was consciously endorsed in the past — [Clark & Chalmers, "The Extended Mind," Analysis 1998, DOI 10.1093/analys/58.1.7](https://doi.org/10.1093/analys/58.1.7) **[canonical]**

### Inferences
- **Provenance is the master property.** The extended-mind "automatic endorsement" criterion means the user will trust what the corpus returns. If AI-generated text is indistinguishable from user-endorsed text, AI output silently becomes "part of the user's mind" without ever having been endorsed. Therefore every unit needs an origin class: `human-authored`, `quoted/sourced` (with locator), `ai-generated` (with model, date, inputs), `ai-proposed → human-accepted` (endorsement event recorded). This is the Clark–Chalmers criterion turned into a data field.
- **Temporality should be bi-temporal and belief-oriented:** `valid_time` (when the claim is/was true in the world or when I believed it) vs `recorded_time` (when written). Supersession should be a link (`supersedes:`), never an overwrite — required for self-knowledge (§1) and for avoiding Teevan-style "changed results break re-finding."
- **Confidence:** a 3–4 level coarse status (e.g., `seedling / working / settled / abandoned`, or `hunch / believe / confident`) is maintainable; numeric probabilities are not, except for explicit forecasts.
- **Messiness tolerance:** structure should be *inferred and proposed* by AI into a sidecar layer, never required at capture time. Required fields at capture: none beyond what the system can auto-stamp (time, device, origin).
- **Stable identity:** notes and claims need IDs that survive renames (Teevan: change hampers re-finding; agents need durable references for citations).

### Gaps
- No empirical study found comparing claim-level vs note-level provenance for personal corpora.
- No evidence found on what level of epistemic annotation individuals actually sustain long-term.

---

## 3. Theory and history: what the canon actually requires

### Takeaway
The canon converges on four ideas that remain unsolved and map directly onto requirements: **associative trails** (Bush), **co-evolution of human capability with tools and methods** (Engelbart), **visible, versioned, transcluded connections** (Nelson), and **division of labor where the machine does the clerical "getting into position to think" work** (Licklider). Cognitive science adds **extended mind** (trust/endorsement criteria), **transactive memory** (knowing *who/where* knows), and **desirable difficulties** (the effort the machine must not remove).

### Cited Findings
- **Bush (1945):** the memex, a personal device storing one's books, records, and communications, with *associative trails* linking items that can be named, stored, and shared with others — [Vannevar Bush, "As We May Think," The Atlantic, July 1945](https://www.theatlantic.com/magazine/archive/1945/07/as-we-may-think/303881/) **[canonical]**
- **Engelbart (1962):** augmentation of the "H-LAM/T" system (Human using Language, Artifacts, Methodology, in which he is Trained); capability comes from co-evolving tools *and* human methods/training, and from "bootstrapping" — [Engelbart, "Augmenting Human Intellect: A Conceptual Framework," SRI 1962](https://www.dougengelbart.org/content/view/138/) **[canonical]**
- **Licklider (1960):** in a self-study, most of his "thinking" time went to clerical activities of getting into a position to think; proposed man–computer symbiosis where machines do routinizable work and humans set goals and evaluate — [Licklider, "Man-Computer Symbiosis," IRE Trans. Human Factors in Electronics 1960](https://groups.csail.mit.edu/medg/people/psz/Licklider.html) **[canonical]**
- **Nelson:** hypertext for "the complex, the changing and the indeterminate" (1965); Xanadu ideals of transclusion (inclusion by reference with a live link to origin), two-way visible links, and version tracking — [Nelson, ACM '65 paper DOI 10.1145/800197.806036](https://doi.org/10.1145/800197.806036); [Project Xanadu](https://xanadu.com/) **[canonical]**
- **Extended mind:** Clark & Chalmers' Otto/Inga thought experiment and endorsement criteria — [Analysis 1998](https://doi.org/10.1093/analys/58.1.7) **[canonical]**
- **Transactive memory:** groups (e.g., couples) form a distributed memory system in which members encode *who knows what* and rely on each other for retrieval — [Wegner, "Transactive Memory: A Contemporary Analysis of the Group Mind" (1987)](https://doi.org/10.1007/978-1-4612-4634-3_9) **[canonical]**
- **Cognitive offloading** is a strategic trade-off: externalizing reduces internal demand but can reduce memory for offloaded content — [Risko & Gilbert, "Cognitive Offloading," Trends in Cognitive Sciences 2016](https://doi.org/10.1016/j.tics.2016.07.002) **[canonical]**; saving one file can *improve* learning of subsequent material by freeing resources ("saving-enhanced memory") — [Storm & Stone, Psychological Science 2015](https://doi.org/10.1177/0956797614559285) **[canonical]**
- **Google effect replication:** the strong Sparrow et al. (2011) "Google Stroop" effect failed to replicate in large replication efforts; a narrower version (depends on perceived reliability of the store) has partial support — [Hesselmann, PeerJ 2020](https://peerj.com/articles/10325); [Memory 2021](https://informahealthcare.com/doi/full/10.1080/09658211.2021.1962356) **[verified via search]**; original: [Sparrow, Liu, Wegner, Science 2011](https://doi.org/10.1126/science.1207745) **[canonical]**
- **Matuschak & Nielsen:** computers have not been as transformative for thought as language/writing; transformative tools need deep subject-matter insight ("insight through making"); tools for thought are public goods that are costly to build and easy to copy — [numinous.productions/ttft](https://numinous.productions/ttft/) **[verified this session]**
- **Appleton:** tools for thought are cultural practices, not just computational objects — [maggieappleton.com/tools-for-thought](https://maggieappleton.com/tools-for-thought) **[verified via search]**

### Inferences
- **Transactive memory is the right model for human+AI corpus, not "second brain."** The human should know *what the corpus knows and roughly where* (meta-memory), while the corpus holds the detail. This is healthy offloading. It breaks when the human no longer knows what's in it (pure AI-written wikis) or can't evaluate it.
- **Bush's trails are the under-built primitive.** Most PKM tools have links, not *trails* (named, ordered, annotated paths with a narrative). AI makes trails cheap to propose; humans should name and endorse them.
- **Nelson's transclusion = provenance-preserving quotation.** A synthesis note should transclude source spans (block refs) rather than paraphrase without a link — this directly addresses AI hallucinated synthesis.
- **Licklider's split maps to the current division of labor:** AI does filing, linking, indexing, linting, retrieval ("getting into position to think"); human does question-setting, judgment, and writing the claims that matter.
- **Engelbart reminds that methodology/training is half the system** — the corpus design must include rituals (weekly review, belief-revision review) not just software.
- The 2015 "saving-enhanced memory" and 2021 "reliability" findings suggest offloading is *beneficial* when the store is trustworthy and the person retains an index of it — supporting a design that makes the store reliable and keeps the human's mental index alive.

### Gaps
- Licklider's specific self-study percentage (commonly quoted ~85%) was not re-verified this session; use qualitatively.
- No empirical test found of transactive-memory theory applied to human–LLM pairs over long durations.

---

## 4. Frontier thinking 2024–2026 and critiques

### Takeaway
The 2025–2026 frontier shifted from "chat with your notes" (RAG) to **LLM-maintained, persistent, compounding artifacts** (Karpathy's LLM Wiki, April 2026), **context engineering** (curating what the agent sees, with just-in-time retrieval and agent-written notes), **temporal knowledge graphs for agent memory** (Zep/Graphiti), and **vendor memory features** (ChatGPT, Claude). In parallel, the strongest evidence of 2025–2026 is cautionary: AI assistance reduces cognitive engagement, ownership, and skill formation *unless* the user engages actively. The design tension is between Karpathy's "the LLM writes the wiki" and cognitive science's "you remember and understand what you generate."

### Cited Findings
**Karpathy's LLM Wiki (April 2026)**
- An LLM incrementally builds and maintains a persistent, interlinked markdown wiki instead of re-deriving answers from raw documents on every query; "The wiki is a persistent, compounding artifact." — [Karpathy, "LLM Wiki" gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) **[verified this session]**
- Three layers: **raw sources** (curated, immutable; the source of truth; LLM reads but never edits), **wiki** (LLM-generated summaries, entity/concept pages, comparisons), **schema** (a CLAUDE.md/AGENTS.md that defines structure, conventions, and workflows, co-evolved by human and LLM) — [gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) **[verified]**
- Operations: **ingest** (one source may touch 10–15 pages), **query** (answers with citations; good answers filed back as pages), **lint** (contradictions, stale claims, orphans, missing cross-references, data gaps). `index.md` = catalog read first at query time (works at ~100 sources / hundreds of pages); `log.md` = append-only chronological record — [gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) **[verified]**
- Division of labor: human curates sources, explores, asks questions; LLM does summarizing, cross-referencing, filing, upkeep — arguing maintenance burden is why human wikis fail. The gist is "intentionally abstract." Secondary coverage quotes him saying he rarely writes or edits the wiki manually — [gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f); [Techstrong coverage](https://techstrong.ai/features/karpathys-instructions-for-building-an-ai-driven-second-brain/) **[verified via search; the quote is via secondary sources]**
- Obsidian is the common viewer; Obsidian Web Clipper for ingestion — [MindStudio summary](https://www.mindstudio.ai/blog/karpathy-llm-wiki-knowledge-base-pattern) **[secondary]**

**Context engineering**
- Anthropic (Sept 2025) frames context as a finite "attention budget"; recommends *just-in-time* retrieval (keep lightweight references like file paths, load details via tools), CLAUDE.md loaded up front with glob/grep for on-demand retrieval, structured agent note-taking (e.g., NOTES.md) to persist across context resets, compaction, and sub-agents — [Anthropic, "Effective context engineering for AI agents"](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) (content confirmed via [secondary summary](https://agentic-ai.readthedocs.io/en/latest/ContextEngineering/anthropic/)) **[verified via search]**
- LLMs use information in the middle of long contexts less reliably than at the ends — [Liu et al., "Lost in the Middle," arXiv 2307.03172](https://arxiv.org/abs/2307.03172) **[canonical]** — a reason not to dump the whole vault into context even with long windows.
- AGENTS.md is an open convention for a README-for-agents file at repo root — [agents.md](https://agents.md/) **[canonical]**

**AI memory systems**
- MemGPT (now Letta): OS-inspired virtual context management, paging information between a main context and external storage under the LLM's own control — [Packer et al., arXiv 2310.08560 (2023)](https://arxiv.org/abs/2310.08560) **[canonical]**
- Zep/Graphiti: bi-temporal knowledge graph with episodic, semantic entity, and community subgraphs — [arXiv 2501.13956](https://arxiv.org/abs/2501.13956); [Moonlight review](https://themoonlight.io/review/zep-a-temporal-knowledge-graph-architecture-for-agent-memory) **[verified via search]**
- Claude memory: on-demand past-chat search for paid users (Aug 2025); automatic memory to Team/Enterprise (Sept 2025) and Pro/Max (Oct 2025); per-project memory spaces; users can view/edit/delete memories; incognito chats; memory import/export later added — [MacRumors, Oct 23 2025](https://www.macrumors.com/2025/10/23/anthropic-automatic-memory-claude/); [The Decoder](https://the-decoder.com/anthropics-claude-can-now-remember-past-conversations/); [Business Today, Aug 12 2025](https://www.businesstoday.in/technology/news/story/anthropic-adds-chat-history-recall-to-claude-letting-users-resume-projects-across-devices-489000-2025-08-12) **[verified via search; exact dates vary across sources]**
- ChatGPT memory: saved memories plus (from April 2025) referencing past chat history — [OpenAI, "Memory and new controls for ChatGPT"](https://openai.com/index/memory-and-new-controls-for-chatgpt/) **[canonical]**

**Critiques / cognitive-offloading evidence**
- **MIT "Your Brain on ChatGPT" (Kosmyna et al., June 2025):** 54 participants, ~4 months, essay writing in LLM / search-engine / brain-only groups with EEG; brain-only showed strongest, most distributed connectivity, search intermediate, LLM weakest; LLM users reported lower ownership and had trouble quoting their own essays; "cognitive debt" framing. Limitations: small sample (18 in crossover session), preprint/not peer-reviewed at time, narrow sample; popular "47% drop" claims not verifiable in the paper — [arXiv 2506.08872](https://arxiv.org/abs/2506.08872); [LIRNEasia journal club](https://lirneasia.net/2025/12/lirneasia-journal-club-your-brain-on-chatgpt-exploring-the-cognitive-debt-of-ai-assisted-writing); [The Decoder](https://the-decoder.com/mit-study-shows-cognitive-debt-through-chatgpt-heres-what-it-means-in-real-world-practice/) **[verified via search]**
- **Microsoft Research/CMU (Lee et al., CHI 2025):** survey of 319 knowledge workers; higher confidence in GenAI associated with less critical thinking, higher self-confidence with more; critical thinking shifts from information gathering to verification, from problem-solving to response integration, from execution to "task stewardship"; recommends designing for awareness, motivation, and ability barriers — [Microsoft Research](https://www.microsoft.com/en-us/research/?p=1135061); [R&D World](https://www.rdworldonline.com/microsoft-and-cmu-genai-may-undercut-critical-thinking-but-theres-an-antidote/) **[verified via search]**; self-reported, correlational.
- **Anthropic RCT on skill formation (Jan 2026):** 52 mostly junior engineers learning the Trio async library; AI-assisted group scored 17% lower on a mastery quiz (Cohen's d≈0.74, p≈0.01) with no statistically significant speedup; *how* AI was used mattered — high-engagement patterns (conceptual/follow-up questions) scored 65–86% vs low-engagement 24–39%; measured immediately, not long-term — [Anthropic research post](https://www.anthropic.com/research/AI-assistance-coding-skills); [arXiv 2601.20245 (Shen & Tamkin)](https://www.arxiv.org/pdf/2601.20245); [InfoQ](https://infoq.com/news/2026/02/ai-coding-skill-formation/) **[verified via search]**
- Model collapse: training on recursively generated data degrades models, losing distribution tails — [Shumailov et al., Nature 2024](https://doi.org/10.1038/s41586-024-07566-y) **[canonical]** (analogy for a corpus that ingests its own AI summaries).

### Inferences
- **Karpathy's pattern is excellent for *reference knowledge about the world* (sources → compiled wiki), and wrong as a default for *the user's own thinking*.** His design itself keeps raw sources immutable and the LLM wiki as a derived layer — i.e., provenance separation is already built in at the directory level. The extension needed for a *personal* corpus is a third, protected class: **human-authored notes** that the LLM may read, annotate in sidecars, and propose changes to, but not silently rewrite.
- The 2026 Anthropic RCT is the most decision-relevant evidence: harm comes from *delegation patterns*, not AI presence. Design should make the engaged pattern (asking, questioning, generating) the default and make "just give me the answer" an explicit mode.
- The CHI 2025 finding (trust in AI ↓ critical thinking) implies the UI should *calibrate* trust — showing source spans, confidence, and disagreement — rather than maximizing fluency.
- Vendor memory (ChatGPT/Claude) is converging toward user-visible, editable memory, but it lives in the vendor's store. For a durable personal corpus, vendor memory should be treated as a *cache* that can be regenerated from the vault, not as the source of truth.
- The evidence on harm is still thin (small n, short-term, self-report). The report should present it as "credible warning signals," not settled science.

### Gaps
- Could not read Karpathy's original X thread directly; the "rarely ever write or edit the wiki manually" quote comes via secondary coverage.
- No longitudinal (multi-year) evidence on AI-maintained personal wikis; all evidence on Karpathy's pattern is anecdotal/practitioner.
- Linus Lee's specific 2024–2026 essays on this topic were not located in this session.
- Kosmyna et al. peer-review status as of Nov 2026 not confirmed.

---

## 5. What a corpus needs so an AI agent can use it well, without making it worse for the human

### Takeaway
Agents need: a **map** (index/MOC files and a schema/AGENTS.md guide), **stable IDs and addressable spans** (for citations), **cheap machine-readable metadata** (frontmatter: type, origin, dates, status), **summaries at multiple granularities**, and an **append-only log**. The way to avoid degrading the human experience is **layer separation**: agent-facing scaffolding lives in sidecar files, frontmatter, or dedicated folders, never interleaved into human prose; and the agent writes only to its own layer or via reviewable proposals.

### Cited Findings
- Karpathy's design uses `index.md` (catalog read first at query time) and `log.md` (append-only, consistently prefixed for grep) plus a schema file (CLAUDE.md/AGENTS.md) that makes the LLM a "disciplined maintainer" — [gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) **[verified]**; the index approach works at roughly ~100 sources / hundreds of pages and search tools become useful beyond that — [same](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) **[verified]**
- Anthropic recommends lightweight identifiers + just-in-time loading, a memory/notes file the agent maintains, and compaction — [Anthropic context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) **[verified via search]**
- Propositions as retrieval units outperform passages — [Dense X Retrieval](https://arxiv.org/abs/2312.06648) **[canonical]**
- Changing previously seen results hinders human re-finding — [Teevan et al. 2007](https://people.csail.mit.edu/teevan/work/publications/papers/sigir07.pdf) **[verified]**
- Humans prefer navigating their own structure over search — [Bergman et al. 2008](https://dl.acm.org/doi/10.1145/1402256.1402259) **[canonical]**

### Inferences
**Agent-useful, human-neutral (or human-positive) features:**
1. **AGENTS.md / CLAUDE.md at vault root**: folder semantics, origin rules ("never edit files in /notes/ without a proposal"), frontmatter schema, link conventions, how to cite. Also useful to the human as documentation of their own system.
2. **Stable IDs**: frontmatter `id:` (ULID or timestamp) independent of filename; block IDs (`^blockid`) on claims that are cited. Renames don't break citations.
3. **Frontmatter minimum schema** (auto-stamped where possible): `id`, `type` (source / note / claim / question / synthesis / journal / person / project), `origin` (human / source / ai / ai-accepted), `created`, `updated`, `valid_from`/`valid_to` or `as_of` for time-bound claims, `status` (coarse), `source` (URL/citekey + locator), `supersedes` / `superseded_by`.
4. **Multi-granularity summaries in sidecars**: per-note one-line summary and per-folder/topic index generated into `_meta/` or a hidden index DB, not into the note body. Human MOCs (maps of content) remain human-authored and the agent proposes additions.
5. **Append-only log** of agent operations (ingest/lint/proposals) — doubles as audit trail and self-knowledge record.
6. **Claims layer** (optional, derived): agent extracts atomic propositions with back-pointers to block IDs into a sidecar index (SQLite/JSONL) — gives proposition-level retrieval and contradiction detection without forcing the human to write atomically.
7. **Proposal channel**: agent edits to human-authored content arrive as diffs, callouts, or `inbox/` proposals the human accepts/rejects; acceptance is recorded (endorsement event).

**What makes it worse for the human (avoid):** AI text inline in human notes without marking; mass auto-linking that turns the graph into noise; renaming/moving files the human navigates by (breaks spatial/locational memory, cf. Barreau & Nardi, Teevan); forcing schema at capture time; generated summaries replacing originals.

### Gaps
- No empirical work found on how AGENTS.md-style guides affect agent accuracy on *personal* vaults (evidence is for code repositories and anecdotal).
- Scale threshold at which index-file navigation must yield to search/embeddings is only anecdotally given (~hundreds of pages, per Karpathy).

---

## 6. Failure modes of "intelligent" corpora

### Takeaway
The dominant failure mode is **provenance collapse**: AI-generated synthesis becomes indistinguishable from the user's endorsed knowledge or from sources, then gets re-ingested as evidence (a personal-scale model-collapse loop). Close behind: **loss of authorship/understanding** (cognitive debt), **over-reliance with miscalibrated trust**, **privacy leakage and prompt injection** via agents that read untrusted content, and **lock-in** to a model's or vendor's memory format.

### Cited Findings
- **Hallucinated synthesis / citation failure:** LLM answers often lack full citation support — [ALCE, Gao et al. 2023](https://arxiv.org/abs/2305.14627) **[canonical]**; Karpathy's lint step is a *detector* of contradictions/stale claims, not a guarantee — [gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) **[verified]**
- **Recursive self-ingestion:** models trained on their own outputs lose the tails of the distribution — [Shumailov et al., Nature 2024](https://doi.org/10.1038/s41586-024-07566-y) **[canonical]** (analogical to summaries-of-summaries erasing nuance and minority views in a corpus).
- **Loss of authorship and recall:** lower ownership and inability to quote own essays in LLM group — [Kosmyna et al. 2025](https://arxiv.org/abs/2506.08872) **[verified via search]**; generation effect — [Slamecka & Graf 1978](https://doi.org/10.1037/0278-7393.4.6.592) **[canonical]**
- **Over-reliance:** higher trust in GenAI ↔ less critical thinking — [Lee et al., CHI 2025](https://www.microsoft.com/en-us/research/?p=1135061) **[verified via search]**; 17% lower mastery with passive AI use — [Anthropic 2026](https://www.anthropic.com/research/AI-assistance-coding-skills) **[verified via search]**
- **Prompt injection / exfiltration:** an agent combining private data, exposure to untrusted content, and the ability to communicate externally (the "lethal trifecta") can be tricked into leaking data — [Simon Willison, "The lethal trifecta for AI agents," June 2025](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/) **[canonical]**. A personal corpus that ingests web clippings and email is exactly this configuration.
- **Collector's fallacy / hoarding:** capture creates illusion of knowing — [Tietze](https://zettelkasten.de/posts/collectors-fallacy/) **[canonical]**
- **Lock-in/opacity of vendor memory:** vendors have added view/edit/delete and import/export for memory, reflecting user demand for control — [The Decoder on Claude memory](https://the-decoder.com/anthropics-claude-can-now-remember-past-conversations/); [Yahoo/Tech coverage of memory import](https://tech.yahoo.com/ai/claude/articles/anthropics-claude-gets-memory-import-170000093.html) **[verified via search]**

### Inferences
Full failure-mode list with mitigations (design proposals):
| Failure mode | Mechanism | Mitigation |
|---|---|---|
| Provenance collapse | AI text unmarked, later treated as user's view or as a source | Mandatory `origin` on every file/block; AI writes only to `ai/` or sidecars; visual styling (callouts) for AI text |
| Synthesis pollution loop | AI summaries re-ingested as evidence | Retrieval for *evidence* restricted to `sources/` + human notes; AI layer is "derived, regenerable"; can be deleted and rebuilt |
| Citation hallucination | Claims without span-level support | Every AI claim must cite a block ID/quote; automatic verifier checks quote exists verbatim; uncited claims flagged |
| Silent belief overwrite | Agent "updates" a note to current view | Supersede, don't overwrite; bi-temporal fields; git history |
| Cognitive debt / authorship loss | AI drafts replace thinking | Modes: "Socratic" default for thinking notes; generation-first prompts (write your take before AI shows its) |
| Over-trust | Fluent output, no calibration | Show sources + disagreement; surface counter-evidence from the user's own notes |
| Graph noise | Auto-links everywhere | AI links are *suggested*, accepted ones become real |
| Navigational breakage | Agent renames/moves files | Stable IDs; agent forbidden from moving human files without approval |
| Privacy leakage / injection | Untrusted clippings + tools + network | Treat ingested content as data; separate untrusted-ingest agent with no network egress; sensitive folders excluded from cloud models; local models for private tiers |
| Model lock-in | Embeddings, memories, formats tied to a vendor | Plain markdown + YAML; derived indexes rebuildable; model-agnostic AGENTS.md; vendor memory treated as cache |
| Hoarding | Frictionless capture, no processing | Inbox with decay/expiry; "processed?" status; resurfacing that asks for a decision |

### Gaps
- No empirical measurement found of how often AI-maintained personal wikis drift from sources over time.
- No study found on prompt-injection incidents specifically in PKM/Obsidian-agent setups (risk is inferred from the general agent-security literature).

---

## 7. Reference architecture (Obsidian vault + AI, buildable today) and open problems

### Takeaway
A **four-layer, provenance-partitioned vault**: (1) immutable **sources**, (2) protected **human thinking** layer, (3) regenerable **AI-derived** layer (wiki/summaries/claims/indexes), (4) **governance** (AGENTS.md, schema, log, proposals inbox) — with agents that read everything, write only to layers 3–4, and reach layer 2 only via human-accepted proposals. This generalizes Karpathy's raw/wiki/schema split by adding the protected human layer and the endorsement event, which the cognitive-science evidence says is what preserves understanding.

### Cited Findings
- Base pattern (raw immutable / LLM wiki / schema; ingest/query/lint; index.md/log.md) — [Karpathy LLM Wiki gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) **[verified]**
- Just-in-time retrieval, agent notes, compaction — [Anthropic context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) **[verified via search]**
- Bi-temporal invalidate-not-delete facts — [Zep/Graphiti](https://arxiv.org/abs/2501.13956) **[verified via search]**
- Local-first and file-over-app principles — [Ink & Switch](https://www.inkandswitch.com/local-first/); [Steph Ango](https://stephango.com/file-over-app) **[canonical]**
- Retrieval practice and mnemonic medium — [Roediger & Karpicke 2006](https://doi.org/10.1111/j.1467-9280.2006.01693.x); [Quantum Country/TTFT](https://numinous.productions/ttft/)
- Engaged AI use preserves learning — [Anthropic RCT 2026](https://www.anthropic.com/research/AI-assistance-coding-skills) **[verified via search]**

### Inferences (the architecture — design proposal, not evidence)

**Vault layout**
```
vault/
  AGENTS.md            # schema + rules for any agent (model-agnostic); CLAUDE.md symlink
  index.md             # human-curated top-level map; agent may propose edits
  inbox/               # zero-friction capture (voice, clips, quick notes); no required fields
  sources/             # immutable: clippings, PDFs, transcripts, highlights (origin: source)
  notes/               # HUMAN layer: my claims, essays, evergreen notes, journals (origin: human)
  decisions/           # decision records & forecasts with dates and confidence (human)
  ai/                  # DERIVED layer, regenerable: wiki pages, topic syntheses, entity pages
    _index/            # per-folder summaries, claim index (JSONL/SQLite), embeddings
  proposals/           # agent-suggested edits/links/merges awaiting accept/reject
  review/              # generated retrieval-practice prompts, resurfacing queues
  log.md               # append-only agent operations log
  .git/                # versioning = belief history + undo
```

**Data model**
- Frontmatter on every file: `id` (stable), `type`, `origin` (human | source | ai | ai-accepted), `created`, `updated`, `as_of` / `valid_from` / `valid_to` for time-bound claims, `status` (coarse), `source` (citekey/URL + locator), `supersedes`/`superseded_by`, `privacy` (public | private | sensitive — controls which models may see it).
- Block IDs on cited claims; AI syntheses cite `[[note#^block]]` or verbatim quotes, never bare paraphrase.
- Derived claim index: atomic propositions extracted from `notes/` and `sources/` with back-pointers, bi-temporal fields, and `contradicts`/`supports` edges. Rebuilt on demand; never authoritative.

**Agents / operations (each a job from §1)**
1. **Capture/ingest** (resurfacing + recall foundation): normalize inbox items, stamp metadata, file sources, write AI summaries into `ai/`, propose links. Runs on untrusted content → no network egress, no write access to `notes/`.
2. **Recall**: hybrid retrieval (index files → grep/BM25 → embeddings → claim index), answers with span-level citations and explicit abstention; ranks human notes above AI pages; shows origin badges.
3. **Synthesis**: on request or scheduled, drafts topic pages in `ai/` that cite spans; highlights *tensions between my notes over time*; proposes trails (Bush) for the human to name.
4. **Reasoning partner (Socratic default)**: before answering, asks for the user's position (generation-first); then argues using the user's own past notes + world knowledge, labeled separately; logs counter-arguments the user accepted.
5. **Lint/curate**: contradictions, stale `as_of` claims, orphans, broken IDs, uncited AI claims, AI-text-in-human-layer violations; outputs to `proposals/`.
6. **Learning**: generates retrieval prompts from the user's own notes into `review/`; spaced scheduling; human edits prompts (card-writing is a skill per Matuschak & Nielsen).
7. **Self-knowledge**: periodic "belief diff" report using git history + supersession links + decision records: "In March you believed X (note), in October you wrote Y; triggering source: Z."
8. **Output**: drafts only after the user writes an outline/thesis; drafts live in `ai/` until the user rewrites/accepts; acceptance marks `origin: ai-accepted`.

**Model and privacy tiers**
- `privacy: sensitive` → local model only; `private` → approved API with no training/retention; `public` → any. Enforced in the retrieval layer, not by convention.
- Vendor memory (ChatGPT/Claude) is a cache seeded from the vault; the vault is canonical.

**Rituals (Engelbart's "methodology" half)**
- Daily: inbox triage (2–5 min) with resurfaced items requiring a decision (keep/link/discard).
- Weekly: review `proposals/`, accept/reject; review queue.
- Quarterly: belief-diff review and decision-record scoring (forecast calibration).

**Why this satisfies the properties**: provenance (origin field + folder partition + endorsement events); temporality (bi-temporal fields + git); verifiability (span citations + quote verifier); local-first/longevity (plain markdown, git, rebuildable derived layer); low friction (inbox with no required fields, AI does metadata); authorship (protected human layer, generation-first modes); tolerance for mess (structure lives in derived layer).

**Open problems (genuinely unsolved as of Nov 2026)**
1. **Measuring "augmentation" vs "substitution"** — no accepted metric for whether a corpus makes the person smarter vs. just more productive; longitudinal studies absent (all current evidence: short-term, small-n, or self-report).
2. **Claim extraction fidelity** — automatically decomposing messy personal prose into atomic claims without distorting the user's meaning or hedges; no benchmark specific to personal notes.
3. **Belief vs. fact temporality** — bi-temporal models exist for world facts (Zep), but modeling *the user's confidence trajectory* and reasons for change is unaddressed.
4. **Resurfacing policy** — when to interrupt with a past note; no good evidence or models beyond flashcard spacing.
5. **Trust calibration UI** — how to show provenance/confidence without overwhelming; CHI 2025 says trust governs critical thinking but offers no proven UI.
6. **Endorsement at scale** — if the AI proposes hundreds of links/claims weekly, human review becomes rubber-stamping (automation complacency), recreating provenance collapse.
7. **Prompt-injection-safe ingestion** — agents that read the web and hold private data remain structurally vulnerable (lethal trifecta); sandboxing patterns are immature for consumer PKM.
8. **Portability of derived layers** — embeddings and claim graphs are model-specific; regenerability is the stated mitigation but costs are non-trivial at scale.
9. **Scale transition** — when index-file navigation (works at ~hundreds of pages) must give way to search/graph retrieval, and how to keep the human's mental map (transactive "who knows what") as the AI layer grows faster than the human can read.
10. **Self-ingestion loops** — preventing the AI layer from citing itself as evidence over years (personal model collapse); requires strict evidence-scope rules that current tools don't enforce.
11. **Social/transclusion layer** — Bush's shareable trails and Nelson's transclusion across *people's* corpora remain unbuilt in a provenance-preserving, local-first way.

### Gaps
- The reference architecture is a synthesis/design proposal; no source validates it end-to-end.
- No benchmark found that evaluates a full personal-corpus system across all seven jobs.
