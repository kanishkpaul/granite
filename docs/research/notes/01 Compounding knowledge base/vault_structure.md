# Obsidian Vault Architecture and Conventions for a Long-Lived Knowledge Base

Research date: 2026-11-03. Primary sources: Steph Ango (kepano, Obsidian CEO) "How I use Obsidian" (stephango.com/vault) and "File over app"; Obsidian help docs (Properties, Bases) and changelog; Nick Milo / Linking Your Thinking (ACE); Andy Matuschak's evergreen notes; Sébastien Dubois (dsebastien.net, Oct 2026); Obsidian forum threads.

## Folders vs. flat vault vs. minimal folders

### Takeaway
Experienced practitioners converge on few, shallow folders organized by note *type* (or source/ownership), never by topic; topics live in links, properties and MOCs. Kepano goes furthest (most notes in root, no subfolders, navigation by quick switcher/backlinks); Milo's ACE uses three "headspace" folders; Dubois uses type folders with optional PARA/Johnny.Decimal numbering. The common thread is that a note can only sit in one folder, so folders should answer "what kind of file is this," not "what is it about."

### Cited Findings
- Kepano's vault uses "few folders, no nested sub-folders, and little use of the file explorer"; navigation relies on the quick switcher, backlinks, and in-note links. His personal rules include "Avoid folders for organization" and "Avoid multiple vaults" (except a separate publishing vault). — [Steph Ango, How I use Obsidian](https://stephango.com/vault)
- Kepano's folders: **Root** (notes he wrote or that relate directly to him: journal entries, essays, evergreen notes); **References** (notes about outside things: books, movies, places, people, podcasts, named by title); **Clippings** (articles/essays written by others); **Attachments** (images, audio, video, PDFs); **Daily** (`YYYY-MM-DD.md`); **Templates**. The downloadable example vault also has **Categories** and **Notes** folders. — [Steph Ango, How I use Obsidian](https://stephango.com/vault); [kepano-obsidian on GitHub](https://github.com/kepano/kepano-obsidian) (MIT licensed; README describes it as "a bottom-up approach" and "in no way dogmatic")
- Nick Milo's ACE framework splits the vault into three "headspaces": **Atlas** (knowledge; intention "to understand"; organized by relatedness), **Calendar** (time; "to focus"/remember & reflect), **Efforts** (action; "to act"; organized by importance). Milo: "ACE is really about the head spaces we orient our thoughts around," and "structure must be earned"; advises "Do less now" and deferring customizations. — [LYT, ACE Folder Framework](https://blog.linkingyourthinking.com/notes/ace-folder-framework)
- ACE evolved from an earlier ACCESS scheme (Atlas, Calendar, Cards, Extras, Sources, Spaces); Ideaverse Pro 2.0 launched April 2025. One user reports Ideaverse Pro 2.0's folders shifted somewhat back toward PARA (unverified secondhand report). — [LYT newsletter Mar 2025](https://newsletter.linkingyourthinking.com/posts/mar2025); search summary of community sources, not independently verified
- Dubois (Oct 2026): file by note type, not topic, because a note's type doesn't change as interests do; topic folders cause "exclusive categorization" and "retrieval dependence" problems. Keep depth "no deeper than 3 or 4 levels." Use strict type→folder mapping so `path:` searches and Base filters are reliable. Folders and type tags are intentionally redundant: tags survive a misfiled note; folders work in tools that ignore tags (rg, git, AI agents read file paths but not Obsidian tags/settings). — [dsebastien, Structure a Findable Obsidian Vault](https://www.dsebastien.net/structure-a-findable-obsidian-vault-folders-links-dates-and-daily-notes/)
- Dubois's metaphor: "If links and backlinks are like roads, tags are like road signs, folders are like houses and MoCs are maps." Every folder, tag family, property or plugin should make a real search faster, or skip it. — [dsebastien](https://www.dsebastien.net/structure-a-findable-obsidian-vault-folders-links-dates-and-daily-notes/)

### Inferences
- A defensible long-term default: `Daily/`, `References/` (outside things), `Clippings/` (others' writing), `Attachments/`, `Templates/`, plus root (or a single `Notes/`) for your own writing; optionally a `Projects/`/Efforts area if action notes are numerous. Avoid topic folders entirely.
- Kepano's minimalism and Dubois's type folders aren't really in conflict: both file by type/provenance; Dubois simply adds numbering and depth for multi-tool access. The extra folder structure pays off mainly if files will be consumed outside Obsidian (terminal, agents, cloud drives).
- Milo's "structure must be earned" and Dubois's "every structure is a cost" both argue against designing a big taxonomy up front.

### Gaps
- No official Obsidian team "recommended folder structure" exists beyond kepano's personal vault (which is a personal template, not product guidance).
- Could not fetch Milo's detailed ACE subfolder layout (e.g., Atlas/Maps, Atlas/Dots, Atlas/Sources) from a primary source; the fetched LYT page only gives the headspace overview.

## Properties/frontmatter schema, and how Properties and Bases change practice

### Takeaway
Since Properties (1.4, Aug 2023) and Bases (core plugin, public in 1.9.10, Aug 2025), the best practice is a small, vault-wide, reusable set of plain YAML properties (short names, list types where values may multiply, links quoted in properties) that Bases views read from. Kepano organizes primarily by a `categories` property feeding Bases overview pages. Bases views live in `.base` files (or code blocks) while the data stays in the notes' YAML, so the knowledge survives even if the view layer doesn't.

### Cited Findings
- **Properties history:** Introduced in Obsidian 1.4.0 (early access), publicly released in 1.4.5 on **2023-08-31**: "a simple and durable way to add tags, links, dates, and other metadata"; data "is still stored as YAML frontmatter." Links in properties use quoted wikilinks, e.g. `link: "[[Link]]"`. 1.4.10 disallowed empty lines before frontmatter. — [Obsidian changelog 1.4.5](https://obsidian.md/changelog/2023-08-31-desktop-v1.4.5); [changelog 1.4.10](https://obsidian.md/changelog/2023-09-11-desktop-v1.4.10)
- **Property types:** Text, List, Number, Checkbox, Date, Date & time, Tags. Default properties: `tags`, `aliases`, `cssclasses` (all lists). Singular `tag`, `alias`, `cssclass` were deprecated in 1.4 and support was **dropped in 1.9**. Once a type is assigned to a property name, it applies vault-wide. **Nested properties are not supported** (viewable only in source mode). Markdown formatting isn't rendered in properties; hashtags inside text properties don't create tags. JSON frontmatter is read but re-saved as YAML. — [Obsidian Help: Properties](https://obsidian.md/help/properties)
- Kepano stores property types in `.obsidian/types.json`. — [Steph Ango, How I use Obsidian](https://stephango.com/vault)
- **Bases history:** Bases arrived as an early-access core plugin in 1.9.0 (Catalyst only); 1.9.2 made breaking changes to formula syntax and the `.base` file format; **1.9.10 (Aug 2025) made Bases available to all users**, alongside a Footnotes view core plugin and the end of `tag`/`alias`/`cssclass` support (Format converter gained a migration function). — [Neowin 1.9.0](https://www.neowin.net/news/obsidian-190-launches-with-new-file-format-footnotes-view-plugin-and-more/); [Neowin 1.9.2](https://www.neowin.net/news/obsidian-192-brings-breaking-changes-ui-improvements-and-several-bug-fixes); [Neowin 1.9.10](https://www.neowin.net/news/obsidian-1910-lands-with-a-new-core-plugin-bug-fixes-and-more/); [APKMirror 1.9.10, uploaded 2025-08-19](https://www.apkmirror.com/?p=10407557)
- **What Bases are:** a core plugin for "database-like views of your notes"; table rows = files, columns = properties; filters, sorting, formulas; multiple views per base; layouts table, list, cards, kanban, map (plus community layouts). Defined in a `.base` file or embedded in a Markdown code block. "All Bases data is stored in your local Markdown files and their properties." — [Obsidian Help: Bases](https://obsidian.md/help/bases)
- **Recent Bases changes (2026):** kanban layout in 1.14.0 (2026-09-02); Group menu (reorder/hide/add groups) in 1.14.3 (2026-09-29); filter reordering in 1.15.0 (2026-10-22). Also 1.15.0 added URI/CLI commands to append/prepend under a heading; 1.14.0 added native Quick Capture on iOS. — [Obsidian changelog](https://obsidian.md/changelog/)
- **Kepano's schema guidance:** notes are mainly organized by a `categories` property feeding Bases overview pages; "Always pluralize categories and tags"; a `genre` property shared across media types so items surface together across categories. Common property groups: dates (`created`, `start`, `end`, `published`), people (`author`, `director`, `cast`, `host`), themes (`genre`, `type`, `topic`, related notes), locations (`neighborhood`, `city`, `coordinates`), and `rating`. Property names should be short and reusable across categories (`start`, not `start-date`). Use **list** type instead of text when a value might later hold multiple links/values. Ratings are integers 1–7 (7 "Perfect", 4 "Passable", 1 "Evil"). — [Steph Ango, How I use Obsidian](https://stephango.com/vault)
- Dubois: track `created` and `updated` in properties for notes without a date in the filename; keep `created` separate from the daily-note link (the link records when an idea entered the system, not file creation). — [dsebastien](https://www.dsebastien.net/structure-a-findable-obsidian-vault-folders-links-dates-and-daily-notes/)
- The `up` property (e.g. `up:: [[PKM MOC]]`) appears in LYT-style notes as a pointer to a parent MOC, but no primary source describing Milo's rule for it was found. — [LYT notes example via search](https://notes.linkingyourthinking.com/Cards/The+3+Phases+of+MOCs) (convention example only)

### Inferences
- Recommended minimal standardized schema (synthesized from kepano + Dubois): `categories` (list of links, e.g. `"[[Books]]"`), `created` (date), `tags` (list, sparingly), `aliases` (list), plus per-category fields (`author`, `source`/`url`, `rating`, `status`, `start`/`end`) and optionally `up`/`related` (list of links). Make every link-valued field a list from day one.
- Because Bases read plain YAML and nested properties aren't supported, keep schemas flat; anything nested will be invisible to Bases and the Properties UI.
- Making `categories` a link (rather than a tag) means each category is itself a note that can host an embedded base (the "overview page"), merging the MOC and query patterns.
- The `.base` file format had a breaking change in 1.9.2, so view definitions are less durable than the YAML data; treat bases as disposable views over durable data.

### Gaps
- Did not verify `types.json` structure against official docs (the Properties help page doesn't mention it; only kepano's page does).
- No official guidance found on a canonical `status` or `source` vocabulary.

## Tags vs. links vs. properties

### Takeaway
Links (in body or in link-valued properties) are for things that deserve or might deserve their own note; properties are for structured, queryable attributes (type/category, dates, people, ratings); tags are a lightweight cross-cutting label best kept few, flat, and pluralized. Kepano uses a `categories` link property as the main organizer rather than tags.

### Cited Findings
- Kepano organizes primarily via the `categories` property (links to category notes) and pluralizes both categories and tags; he links "profusely." — [Steph Ango, How I use Obsidian](https://stephango.com/vault)
- Dubois: links/backlinks are "roads," tags are "road signs," folders are "houses," MOCs are "maps"; type tags duplicate folders deliberately for resilience. — [dsebastien](https://www.dsebastien.net/structure-a-findable-obsidian-vault-folders-links-dates-and-daily-notes/)
- Hashtags inside text properties don't create tags; tags must go in the `tags` property (Tags type) or inline. — [Obsidian Help: Properties](https://obsidian.md/help/properties)
- Practitioner accounts (anecdotal): a four-year reflection advises keeping tag hierarchies mostly flat (deep nesting recreates the folder problem); one long-term user reports ~800 tags with ~50 used often and a long tail rarely used; another argues specific concepts deserve links while broad subjects are better served by MOCs than tags. — search summary of [Reflections on 4 years of Writing with Obsidian](https://website-7lu.pages.dev/posts/obsidian-four-year-reflections) and other practitioner blogs (secondhand; specific attributions to individual posts not verified)

### Inferences
- Decision rule: *If it's a thing (person, book, concept, project), link it. If it's an attribute you'll filter or sort by, make it a property. If it's a transient state or workflow marker (`#todo`, `#draft`), a tag is fine.* Tag sprawl is the most commonly reported long-term failure.
- Link-valued properties are preferable to tags for categories because links survive renames (Obsidian updates them) and the target note can carry its own content/base.

### Gaps
- No official Obsidian documentation states a tags-vs-links policy; this is practitioner consensus.

## Note naming: concept titles, Zettel IDs, renames, aliases

### Takeaway
Descriptive, concept-oriented titles are the dominant practice in Obsidian because the app updates links automatically on rename, removing the main reason for opaque IDs. Kepano uses a hybrid: reference notes named by their real title; "unique notes" prefixed with a `YYYY-MM-DD HHmm` timestamp plus optional title. Aliases cover alternate names.

### Cited Findings
- Kepano: dates `YYYY-MM-DD` everywhere; unique notes prefixed `YYYY-MM-DD HHmm` with an optional descriptive title; reference notes named by their title (e.g. `Book title.md`); daily notes `YYYY-MM-DD.md`. — [Steph Ango, How I use Obsidian](https://stephango.com/vault)
- Matuschak: well-titled evergreen notes work "like APIs" — the title abstracts the whole note so it can be referenced by that handle; titles should be sharp complete phrases, affirmatively framed, and notes atomic (separation of concerns). — [Andy Matuschak, Evergreen note titles are like APIs](https://notes.andymatuschak.org/Evergreen_note_titles_are_like_APIs)
- Forum consensus (no official position): Obsidian's rename-and-relink behavior is cited as the main reason descriptive filenames work; IDs are defended by some long-term users with thousands of notes and by those referencing notes from external systems (e.g., task managers); aliases (added in 0.9.16) can pair an ID filename with a readable name; timestamp IDs can collide when notes are created in the same minute. — [Forum: H1/title as display name](https://forum.obsidian.md/t/use-h1-or-front-matter-title-instead-of-or-in-addition-to-filename-as-display-name/687/103); [Forum: Importance of naming with zettelkasten IDs](https://forum.obsidian.md/t/importance-of-naming-with-zettelkasten-ids/16140); [Forum: Unlinked mentions and prefixer](https://forum.obsidian.md/t/unlinked-mentions-and-zettelkasten-prefixer/2428); [Forum: backlink suggestion for zettelkasten names](https://forum.obsidian.md/t/backlink-suggestion-for-zettelkasten-style-names/1290/7)
- Dubois: ISO dates in names — daily `YYYY-MM-DD`, weekly `YYYY-Www`, monthly `YYYY-MM`, meetings `YYYY-MM-DD - Topic`; typing `2025-03` in quick switcher or `file:2025-03` in search returns everything from that month. — [dsebastien](https://www.dsebastien.net/structure-a-findable-obsidian-vault-folders-links-dates-and-daily-notes/)

### Inferences
- Recommended: concept/claim titles for your own evergreen notes; canonical real-world names for reference notes; ISO date prefixes only for time-bound notes (journal, meetings, fleeting/unique notes). Add `aliases` for synonyms/acronyms so link autocomplete and unlinked-mentions still find them.
- Renames are safe inside Obsidian but not outside it (git, other editors, scripts won't rewrite links); if many external tools will touch the vault, stable filenames matter more.

### Gaps
- No quantitative evidence on ID vs. title outcomes at 5–10 year scale.

## Linking practices, MOCs, and when to split notes

### Takeaway
Link profusely, link first mentions, and treat unresolved links as deliberate placeholders. Build MOCs/index notes only when a topic becomes hard to hold in your head (a "mental squeeze point"), and annotate links in them; increasingly, MOCs are category notes with an embedded base.

### Cited Findings
- Kepano: "Link profusely," link the first mention of each subject; unresolved links are deliberate "breadcrumbs" for notes to create later; journal entries in root link out to reference notes, which hold properties, ratings and thoughts. "Random revisit": every few months use random-note and local graph to revisit old notes, add missing links, and fix formatting. — [Steph Ango, How I use Obsidian](https://stephango.com/vault)
- Dubois: create a MOC at the "Mental Squeeze Point," not on day one; add a sentence of context per link; many MOCs can be generated from queries/metadata; consider one MOC-of-MOCs as top-level entry. Link generously but purposefully; prefer inline links; avoid generic link text. — [dsebastien](https://www.dsebastien.net/structure-a-findable-obsidian-vault-folders-links-dates-and-daily-notes/)
- Milo-adjacent sources: MOCs "start out as singular notes" (Five Levels of Emergence); a secondary wiki cites a rough 5–10-note threshold per cluster (not verified as a Milo quote). — [LYT: The 3 Phases of MOCs](https://notes.linkingyourthinking.com/Cards/The+3+Phases+of+MOCs); [AI Wiki PKM: Maps of content](https://ai-wiki-pkm.pages.dev/maps-of-content) (secondary)
- Matuschak: notes should be atomic and titled as concept handles (the basis for splitting: one note per idea that you'd want to reference by name). — [Andy Matuschak](https://notes.andymatuschak.org/Evergreen_note_titles_are_like_APIs)

### Inferences
- Split rule: split when a section is something you'd want to link to by name from elsewhere; this is cheaper and more portable than block references, which rely on Obsidian-specific `^block-id` syntax.
- An `up` property is a cheap, portable way to give every note a parent MOC/category and make hierarchy queryable in Bases without folders.

### Gaps
- Did not find primary-source guidance on block references or on link density metrics; block-reference portability was not researched directly.
- Did not find Milo's own definition of the `up` convention.

## Daily/periodic notes and the capture-to-permanent flow

### Takeaway
Two credible models conflict: kepano never writes in daily notes (they exist as link targets; he writes dated "unique notes" that link to the day), while Dubois captures into the daily note first and processes weekly into atomic notes. Both make the daily note a time-based hub reached via links/backlinks, and both roll up via periodic reviews.

### Cited Findings
- Kepano: daily notes `YYYY-MM-DD.md` in `Daily/` are "never written in directly; they exist to be linked to." "Fractal journaling": quick thoughts through the day, compiled every few days, reviewed monthly, monthly reviews reviewed yearly. One to-do list per week. Avoids automating review with LLMs: "Don't delegate understanding." — [Steph Ango, How I use Obsidian](https://stephango.com/vault)
- Dubois: capture raw ideas in the day's note, link every new note from the day's note (a "Discoveries" timeline section), split captures into named atomic notes during a weekly review and replace raw text with links; weekly/monthly/quarterly/yearly notes give a zoomable timeline. — [dsebastien](https://www.dsebastien.net/structure-a-findable-obsidian-vault-folders-links-dates-and-daily-notes/) — conflicts with kepano's "never write in daily notes" approach
- Milo's Calendar headspace: time-based notes oriented around "What's on your mind?" — [LYT ACE](https://blog.linkingyourthinking.com/notes/ace-folder-framework)
- Native Quick Capture on iOS arrived in 1.14.0 (2026-09-02); 1.15.0 (2026-10-22) added URI/CLI commands to append/prepend under a heading — relevant for automated capture into daily notes. — [Obsidian changelog](https://obsidian.md/changelog/)

### Inferences
- Either way, the durable pattern is: capture is cheap and time-stamped; permanence comes from extracting titled, linked notes during a regular review; the daily note's backlinks panel becomes the chronological index.
- Kepano's model keeps daily files empty and makes each capture a separate file (better for linking/splitting); Dubois's keeps capture in one file (lower friction, but needs disciplined processing).

### Gaps
- No longitudinal evidence on which capture model leads to better long-term retention.

## Attachments, templates, and future-proofing (file over app, plugin lock-in)

### Takeaway
Keep everything as plain Markdown + YAML + standard files; avoid non-standard Markdown and logic embedded in notes (e.g., Dataview queries) because those render only inside a plugin. Bases is a core plugin whose data stays in YAML, so losing it only loses views. Templates should be simple, composable property scaffolds.

### Cited Findings
- "File over app" (kepano, 2023-07-01): "Apps are ephemeral, but your files have a chance to last"; digital work that lasts should be in files you control in easy-to-read formats; he helps build Obsidian but doesn't assume it lasts forever. — [Steph Ango, File over app](https://stephango.com/file-over-app)
- Kepano's rules: "Avoid non-standard Markdown"; nearly every note starts from a template; each category has its own template with properties at the top; templates are composable (e.g., Person + Author on one note). Attachments go in a single `Attachments/` folder. Publishing uses a separate vault synced via Obsidian Git to GitHub, built with Jekyll on Netlify. — [Steph Ango, How I use Obsidian](https://stephango.com/vault)
- Bases data lives in local Markdown files and properties. — [Obsidian Help: Bases](https://obsidian.md/help/bases)
- Dataview query results appear only in rendered view, not in graph, backlinks, git diffs, or to an AI agent reading raw files; Bases and Dataview read the same YAML; deleting a base loses only the view. Dataview's maintenance status is disputed in community sources (one says no longer actively developed, another says not abandoned). — [dsebastien, Complete Guide to Dataview](https://www.dsebastien.net/the-complete-guide-to-dataview-in-obsidian/); [Obsidian forum: portability thread](https://forum.obsidian.md/t/are-we-moving-away-from-portability-how-much-is-obsidian-locking-our-notes-in/19329); [MPU forum: Bases](https://talk.macpowerusers.com/t/obsidian-bases-plugin/42604) (note: some "no lock-in" claims come from vendors with a stake, e.g. obsibrain)
- Web Clipper: official free extension (Chrome, Firefox, Edge, Safari) saving web pages as Markdown with page metadata mapped to Properties via templates (variables, filters, logic); destination folder set per template (commonly `Clippings`). Clipped images may stay as remote URLs unless "Download attachments for current file" is run. — [Obsidian Help: Web Clipper capture](https://help.obsidian.md/web-clipper/capture); [Obsidian forum: default folder](https://forum.obsidian.md/t/obsidian-web-clipper-set-default-folder/96186); [dsebastien](https://www.dsebastien.net/structure-a-findable-obsidian-vault-folders-links-dates-and-daily-notes/)
- Dubois: for large/shared files (videos, contracts), keep a small pointer note in the vault describing and linking the file rather than storing it. Folders and ISO-date names work in file managers, terminal, git and AI agents, which don't read Obsidian tags/settings. — [dsebastien](https://www.dsebastien.net/structure-a-findable-obsidian-vault-folders-links-dates-and-daily-notes/)

### Inferences
- Portability checklist: wikilinks are the main Obsidian-specific syntax that's widely tolerated (many tools support them; Markdown-link mode is an option for maximum portability); avoid embedded query languages, block IDs, plugin-specific inline fields (`key:: value`), and callout/plugin syntax for core content; put structured data in flat YAML; keep `.base` files as replaceable views.
- Download clipped images locally (a single `Attachments/` folder) so clippings don't rot when remote URLs die.
- Version the vault with git for 10-year durability and history independent of any sync service.

### Gaps
- Web Clipper launch date/version not confirmed from a primary source in this research (search results gave no date).
- Did not fetch official docs for attachment-location settings ("Default location for new attachments"); attachment advice above relies on kepano and Dubois only.
- Dataview's current maintenance status unresolved; check its GitHub repo.
