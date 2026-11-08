# Zotero (as of November 2026) — integration surfaces and limits for a native macOS knowledge-base app

Research date: 2026-11-08. Scope: Zotero itself and paper-ingestion infrastructure for a personal Swift/SwiftUI knowledge app. General Mac stack and AI architecture are out of scope.

## 1. Current state: Zotero 8, 9 and 10; reader, annotations, notes, AI and mobile

### Takeaway
Zotero has moved to a fast release cadence. Zotero 8 shipped on 2026-01-22, Zotero 9 on 2026-04-10 and Zotero 10 on 2026-08-17. Zotero 10 is the current major version. It added local-API writes, nested advanced search with annotation conditions, undo/redo, batch editing and a reflowable PDF Reading Mode. Zotero core still has no built-in LLM or AI features: all AI comes from third-party plugins. Read Aloud ("Zotero Voices", with Standard and Premium tiers) is the closest thing to a first-party "smart" feature. iOS and Android apps both exist.

### Cited Findings
- **Zotero 8 (released 2026-01-22):** it grew out of the Zotero 7.1 beta and was renamed after moving to a Firefox 140 base. Changes include:
  - one unified citation dialog with two modes, replacing three older input methods;
  - attachment filenames that stay in sync with parent metadata automatically;
  - a Linux ARM64 build;
  - dropped support for macOS 10.14 and earlier, and for Windows 7 and 8.
  — [Zotero blog: Zotero 8](https://www.zotero.org/blog/zotero-8/); [heise](https://www.heise.de/en/news/Zotero-8-Reference-management-with-new-citation-dialog-11153978.html); [Forum: Announcing Zotero 8](https://forums.zotero.org/discussion/129152/announcing-zotero-8)
- **Faster release cycle (announced 2026-01-22):** feature releases roughly every 6–10 weeks, with changes appearing in the Zotero Beta between releases and maintenance point releases such as 8.0.1. — [Zotero blog news category](https://www.zotero.org/blog/category/news/); [Forum: A faster release cycle](https://forums.zotero.org/discussion/129153/a-faster-release-cycle-for-zotero)
- **Zotero 8 added a native citation-key field** in its internal CSL format. Zotero copied existing Better BibTeX keys into it. This caused breakage in BBT, Zettlr and others: missing keys, CSL-JSON exports without `id`, and crashes. Zotero 8.0.4 disabled the BBT versions known to crash Zotero. — [Zettlr blog, 2026-03-07](https://zettlr.com/post/on-the-recent-issues-with-zotero-8-and-better-bibtex)
- **Zotero 9 (2026-04-10):**
  - Read Aloud on desktop for PDFs, EPUBs and snapshots, using "Zotero Voices" with Standard and Premium tiers;
  - a "Recently Read" collection with a Last Read time that syncs across devices;
  - "Add Annotation" in the word-processor plugins, which inserts annotations with active citations;
  - "Added By" and "Modified By" columns in group libraries;
  - about 20% lower startup memory, and less disk used by file copies on macOS;
  - sign-in through the browser, enabling password managers and 2FA (beta).
  — [Zotero blog news](https://www.zotero.org/blog/category/news/)
- **Zotero 10 (2026-08-17):**
  - advanced search moved into the main window, with nested condition groups, annotation conditions and accent-insensitive matching;
  - much faster phrase and attachment-content search;
  - multi-collection and multi-library selection;
  - undo/redo for many operations;
  - batch editing of fields (not item type, creators or tags yet);
  - PDF Reading Mode, a reflowable view where you can still highlight and annotate;
  - sentence-level Read Aloud highlighting;
  - an improved Safari connector, citation preview and lower reader-tab memory use.
  — [Zotero blog news](https://www.zotero.org/blog/category/news/)
- **Zotero 10 also adds local HTTP API writes**, with per-app authorization. See section 3. — [Zotero Local API docs](https://www.zotero.org/support/dev/web_api/v3/local_api)
- **iOS:** Read Aloud reached Zotero for iOS on 2026-10-05. It covers PDFs, EPUBs and snapshots; skips in-text citations, headers, footers and tables; has an "Annotate Sentence" button; and keeps playing in the background. — [Zotero blog news](https://www.zotero.org/blog/category/news/)
- **Android:** the official Zotero for Android app launched around June 2025. It syncs personal and group libraries and supports PDF annotation. EPUB and snapshot annotation were "in development" at launch. — [Zotero blog: Zotero for Android](https://www.zotero.org/blog/zotero-for-android/); [AlternativeTo, June 2025](https://alternativeto.net/news/2025/6/zotero-launches-android-app-with-pdf-annotations-library-sync-and-barcode-scanning)
- **No AI features in core:** none of the 2026 Zotero blog posts (Zotero 8 to 10, iOS Read Aloud) announces LLM or AI features. — [Zotero blog news](https://www.zotero.org/blog/category/news/)
- **Third-party AI plugins (2026):**
  - **Beaver:** an agentic research sidebar with sentence-level citations. It is bring-your-own-key (Google, DeepSeek, custom endpoints) and was in beta. — [Zotero forum: Beaver](https://forums.zotero.org/discussion/126573/)
  - **PapersGPT:** multi-provider PDF chat (GPT, Claude, Gemini, local models), with MCP support. — [PapersFlow review](https://papersflow.ai/blog/papersgpt-zotero-review); [awesome.ecosyste.ms](https://awesome.ecosyste.ms/projects/github.com%2Fpapersgpt%2Fpapersgpt-for-zotero)
  - **llm-for-zotero:** AGPL-3.0; a reader-side assistant plus library-wide chat. — [everydev](https://www.everydev.ai/tools/llm-for-zotero)
  - **AIdea:** supports Ollama and LM Studio. — [awesome.ecosyste.ms](https://awesome.ecosyste.ms/projects/github.com%2Fvisterainer%2Faidea-zotero)
  - **Aria (older):** reportedly confirmed only for Zotero 6. — [getcoai](https://getcoai.com/tool-detail/aria/163659/)
  - A 2026 roundup names Beaver for agentic search and PapersGPT for PDF chat. The source is vendor-adjacent. — [PapersFlow: best Zotero plugins 2026](https://papersflow.ai/blog/best-zotero-plugins-2026)
- **Plugin trust warning:** a 2026 forum thread reports that the zotero-reference, zotero-gpt and zotero-style plugins ship obfuscated code that does not match their repos. This raises AGPL and security concerns. — [Zotero forum](https://forums.zotero.org/discussion/comment/507862)

### Inferences
- The six-to-ten-week cadence plus the Zotero 8 citation-key episode mean that anything coupled to Zotero internals will break more often than in the Zotero 5/6 era. That covers SQLite schema, plugin APIs and BBT behaviour. A custom app should prefer the versioned HTTP APIs, which are v3 and stable, over the DB schema.
- Zotero's reader is now strong: PDF, EPUB and snapshot reading, Reading Mode, Read Aloud, mobile annotation. Replacing it in a personal Swift app with PDFKit is a large effort for marginal gain. Let Zotero stay the reading and annotation surface, and pull its annotations into the knowledge app.
- Because Zotero has no built-in AI, the knowledge app is free to own AI and synthesis without competing with a first-party feature.

### Gaps
- No official Zotero changelog was fetched for 10.x point releases, or for any beta after 10 (Zotero 11 would be roughly due by late 2026 at the stated cadence; not verified).
- No stable Zotero 9 or 10 compatibility statement was found for Better Notes. Only a v3.0.0-beta.7 targets Zotero 8 ([newreleases](https://newreleases.io/project/github/windingwind/zotero-better-notes/release/v3.0.0-beta.7)).
- Zotero Voices Premium pricing was not found.
- The current state of the Android app (EPUB annotation, Read Aloud) was not verified.

## 2. Data model and storage: zotero.sqlite, storage/, attachments, full-text cache, safe reading

### Takeaway
All metadata, notes, tags and annotations live in `~/Zotero/zotero.sqlite`. Files live in `~/Zotero/storage/<8-char-KEY>/`. Zotero holds an exclusive SQLite lock by default, so a live read fails with "database is locked". The standard pattern is to copy the DB (plus any `-wal`) and read the copy, or better, use the local API. Zotero says DB access must be read-only, and the schema can change between releases.

### Cited Findings
- **Location (macOS):** the default data directory is `/Users/<username>/Zotero`, unless changed in Advanced settings.
- **What `zotero.sqlite` holds:** item metadata, notes and tags. The page calls it "the most important file in the data directory".
- **`storage/`:** contains subfolders with 8-character names (e.g. `N7SMB24A`) holding imported files. Linked files are "not copied into this subfolder".
- **Other contents:** `fulltext.sqlite` indexes full-text content for faster searching. Zotero also creates `translators`, `styles`, `locate`, `logs` and `pipes` folders.
- **Backups:** `zotero.sqlite.bak` and `zotero.sqlite.1.bak` are automatic backups, made at most once a day.
- **Copying:** the page says to be sure Zotero is closed before copying, moving or deleting these files.

— [Zotero support: The Zotero Data Directory](https://www.zotero.org/support/zotero_data)

- **Official guidance on direct access:**
  - access "should be done only in a read-only manner"; writing while Zotero runs "can easily result in a corrupted database";
  - "A caching layer breaks the normal file-locking in SQLite that allows for safe concurrent file access";
  - "the SQLite database structure can change between Zotero releases";
  - direct writes bypass validation and referential integrity and can break sync;
  - "it is generally preferable to access Zotero library data via either the Web API or JavaScript API".
  — [Zotero support: Direct SQLite Database Access](https://www.zotero.org/support/dev/client_coding/direct_sqlite_database_access)
- **Exclusive locking:** Zotero uses SQLite exclusive locking, controlled by the hidden pref `extensions.zotero.dbLockExclusive` (default true). The pref was introduced in an old 2.x-era commit, and its behaviour in current builds was not verified. — [commit mirror](https://ayakael.net/mirrors/zotero/commit/245954b8765c463209baee2bafe9c792ea3bed7a)
- **What users hit:** Python readers get "sqlite3.OperationalError: database is locked" while Zotero is open. Moderators say it is not safe to read a DB in use by another program. The common workaround is to copy to a temp file and query the copy. One user reports that `PRAGMA journal_mode=WAL` did not help. — [Zotero forum: access zotero.sqlite while running](https://forums.zotero.org/discussion/comment/351882); [Zotero forum: Python sqlite3 access denied](https://forums.zotero.org/discussion/comment/305194)
- **Annotations table:** annotations (Zotero 6+) live in `itemAnnotations`. Columns are `itemID` (PK; the annotation is itself an item), `parentItemID` (the attachment item, e.g. the PDF, not the top-level bibliographic item), `type` (integer), `authorName`, `text`, `comment`, `color`, `pageLabel`, `sortIndex`, `position` (JSON), and `isExternal`. There is an index on `parentItemID`. — [schema gist](https://gist.github.com/atomotic/e96982253136dcd253f8376ded2fd0e5); [schema-repair commit](https://ayakael.net/mirrors/zotero/commit/7700cd776aa18bcd8b5d04d2b2a9f3d3b6e363f8); [isExternal commit](https://ayakael.net/mirrors/zotero/commit/ebc0ca2462f23a9e54667a5d237b2a4a86b86e07); [zotero-dev: ItemAnnotation fields](https://groups.google.com/g/zotero-dev/c/1BZJIJ-Gd0o)
- **Annotation tags:** these are stored through the normal item-tag tables, because annotations are items. — [Zotero forum: Annotation tags in SQLite](https://forums.zotero.org/discussion/100496/annotation-tags-in-zotero-sqlite-database)
- **Annotations inside the PDF:** "external" annotations, meaning ones embedded in the PDF file rather than made in Zotero, are flagged via `isExternal`. — [commit](https://ayakael.net/mirrors/zotero/commit/ebc0ca2462f23a9e54667a5d237b2a4a86b86e07)
- **Full-text cache:**
  - each indexed attachment folder in `storage/` gets hidden `.zotero-ft-cache` (the extracted plain text) and, for PDFs, `.zotero-ft-info` files;
  - linked files also get a `storage/<KEY>/` folder holding just these caches;
  - no cache is created for protected or image-only PDFs;
  - in download-as-needed mode with "Sync full-text content" enabled, folders can hold only these files;
  - Zotero staff say the folder is Zotero-managed.
  — [Zotero forum: where is the full-text index stored](https://forums.zotero.org/discussion/comment/132301); [Zotero forum: folders with only hidden files](https://forums.zotero.org/discussion/95839/folders-in-zotero-storage-with-only-hidden-files); [Zotero forum: ft-cache not created](https://forums.zotero.org/discussion/21422/pdf-is-stored-but-zotero-ft-cache-and-zotero-ft-info-are-not-created)
- **Schema references:** for field names and mappings, the docs point to the Zotero schema on GitHub (`zotero/zotero-schema`) and a CSL/Zotero field index. — [Zotero support: Direct SQLite access](https://www.zotero.org/support/dev/client_coding/direct_sqlite_database_access)
- **Item keys:** keys are 8 characters from the alphabet `[23456789ABCDEFGHIJKLMNPQRSTUVWXYZ]` (this regex also governs locally generated keys for writes). — [Zotero Web API: Write Requests](https://www.zotero.org/support/dev/web_api/v3/write_requests)

### Inferences
- **Schema essentials for a read-only Swift reader**, inferred from the community schema sources above and general Zotero knowledge, so verify against the current schema:
  - `items` (itemID, itemTypeID, key, libraryID, dateAdded/dateModified);
  - an entity–attribute–value design: `itemData` (itemID, fieldID, valueID) → `itemDataValues` (valueID, value) plus `fields` (fieldID, fieldName); title, DOI, date and abstract all live here;
  - `itemCreators` → `creators` (firstName, lastName, fieldMode);
  - `collections` and `collectionItems`;
  - `tags` and `itemTags` (with type 0 = manual, 1 = automatic);
  - `itemAttachments` (parentItemID, linkMode, contentType, path, where `storage:filename.pdf` means a stored file and an absolute or `attachments:`-relative path means a linked file);
  - `itemNotes` (parentItemID, note HTML, title);
  - `itemAnnotations`;
  - `itemRelations` (owl:sameAs / dc:relation URIs);
  - `deletedItems` (trash).
- **Practical "copy-then-read" pattern in Swift:**
  1. Watch `zotero.sqlite` for modification time changes.
  2. Copy `zotero.sqlite` and any `-wal`/`-journal` file to the app's container. Alternatively, open with SQLite URI `file:...?immutable=1&mode=ro`, accepting that this risks reading a torn state.
  3. Read the copy with GRDB.
  4. Resolve stored files at `~/Zotero/storage/<attachmentKey>/<filename>`.
  5. Read `.zotero-ft-cache` as a cheap plain-text source before running heavier PDF parsing.

  The `immutable=1` trick is not documented by Zotero; it is general SQLite behaviour and untested here.
- Because Zotero 10 now exposes full read/write over the local API, direct SQLite should be a fallback. Use it only for bulk initial import or when Zotero is not running. Even then, prefer opening `zotero.sqlite.bak` or a fresh copy.

### Gaps
- No official, current table-by-table schema doc exists. The schema is in `zotero/zotero` source (`resource/schema/userdata.sql`), which was not fetched.
- The integer codes for `itemAnnotations.type` are not documented in the sources found. Community knowledge is 1 = highlight, 2 = note, 3 = image, 4 = ink, 5 = underline, 6 = text; unverified.
- Whether Zotero 10 still defaults to exclusive locking, and whether the `dbLockExclusive` pref still works, is unverified.
- The 54yyyu zotero-mcp README says its local mode "reads come straight from `zotero.sqlite`", but how it avoids the lock was not found. It may copy the file or use read-only/immutable mode.

## 3. APIs: local HTTP API, Web API v3, connector, translation-server, Better BibTeX, CSL

### Takeaway
There are five main programmatic surfaces:
1. **Local API** at `http://localhost:23119/api/`: a Web-API-v3-compatible API. It is read-only in Zotero 7 to 9. Zotero 10+ adds read/write, with a user-approved local key, file uploads and full-text writes.
2. **Web API v3** at `api.zotero.org`: needs a key, offers full read/write and sync, with batch writes of up to 50 objects.
3. **Better BibTeX JSON-RPC** on the same port: citekeys, exports, auto-export and search.
4. **The Zotero translation-server** (Docker, port 1969): turns identifiers or URLs into Zotero JSON and exports formats.
5. **CSL styles and citeproc:** CSL-JSON is exportable from both APIs.

Together these let a Mac app read, create, annotate and cite without touching SQLite.

### Cited Findings
**Local API**

- **History and enabling:** introduced in Zotero 7 beta 88, modelled on the Web API. Enable it in Settings → Advanced: "Allow other applications on this computer to communicate with Zotero". Without it, requests return `403`. — [zotero-dev announcement](https://groups.google.com/g/zotero-dev/c/ElvHhIFAXrY); [Local API docs](https://www.zotero.org/support/dev/web_api/v3/local_api)
- **Users and auth:** use user ID `0` or your own numeric ID. Reads need no auth and are not rate-limited, so any local process can read the library. The docs warn not to expose or forward the port. — [Local API docs](https://www.zotero.org/support/dev/web_api/v3/local_api)
- **Differences from the Web API:**
  - no default or maximum `limit`; results are unpaginated unless requested;
  - `format=atom` returns `501`;
  - group metadata is minimal and read-only;
  - sort order, quicksearch and JSON can differ slightly from the Web API.
  — [Local API docs](https://www.zotero.org/support/dev/web_api/v3/local_api); [Web API basics](https://www.zotero.org/support/dev/web_api/v3/basics)
- **Local-only endpoints:**
  - `/searches/<key>/items` executes saved searches, which the Web API does not do;
  - `/items/<key>/file` and `/file/view` return a `302` redirect to a `file://` URL, and `/file/view/url` returns the path as text. This is the clean way to locate a PDF on disk. — [Local API docs](https://www.zotero.org/support/dev/web_api/v3/local_api)
- **Writes (Zotero 10+):**
  - `POST`, `PUT`, `PATCH` and `DELETE` work for items, collections and saved searches, plus tag deletion, full-text writes and file uploads;
  - changes appear in the UI immediately and sync to zotero.org on the next sync.
- **Local write authorization (Zotero 10+):**
  - request a key with `POST /api/local/authorize`, sending `{appName}` in the body and the `Zotero-Server-ID` header;
  - the user sees an Allow / Always Allow / Deny dialog; the response is a 32-character key, with `remember: true` when the user chose Always Allow;
  - a key granted without Always Allow is single-use;
  - keys are not scoped, so they can write to any library the user can edit;
  - dialog-triggering requests are limited to five per minute (`429` beyond that);
  - users revoke keys with "Clear Write Authorizations".
- **Server ID and versions:** every Zotero 10+ response carries `Zotero-Server-ID`. A mismatch returns `412`, which means discarding cached versions. Writes require the header (`428` if it is missing). Local object versions have no relation to Web API versions.
- **File uploads (Zotero 10+):** a three-step flow (md5, filename, filesize, mtime → POST bytes → register). It applies only to `imported_file` and `imported_url` attachments and handles files up to 4 GB. Partial `PATCH` returns `405`.
- **Full-text writes:** `PUT /items/<key>/fulltext`, or a bulk `POST /fulltext` with up to 10 entries. `GET /fulltext?since=<version>` returns changed full text.

— [Local API docs](https://www.zotero.org/support/dev/web_api/v3/local_api)

**Web API v3**

- **Basics:** base URL `https://api.zotero.org`. Send the `Zotero-API-Version: 3` header. Pass the key via `Zotero-API-Key` or `Authorization: Bearer`; the `key=` query parameter is discouraged.
- **Rate limiting:** honour `Backoff` (which can appear even on successful responses) and `429` with `Retry-After` (use exponential backoff if `Retry-After` is absent). Make no more than 4 concurrent requests.
- **Paging:** `limit` is 1–100 (default 25), with `start` and `Link` headers. `bib` output is capped at 150 items.
- **Formats:** `json`, `atom`, `bib`, `keys`, `versions`, plus export formats `bibtex`, `csljson`, `ris`, `csv` and others. `include=citation` / `include=bib` render via CSL.
- **Search:** `qmode=everything` enables full-text search.

— [Web API basics](https://www.zotero.org/support/dev/web_api/v3/basics)

- **Writes:**
  - up to 50 items, collections or searches per `POST`, and 50 per delete (`413` beyond that);
  - concurrency control via `If-Unmodified-Since-Version` or per-object `version` (`412` on conflict, `428` if missing on delete);
  - `Zotero-Write-Token` is cached for 12 hours;
  - child notes and attachments are created via `parentItem`;
  - batch results come back as `successful`, `unchanged` and `failed` maps;
  - `409` means the library is locked;
  - the key must have write access.
  — [Web API: Write Requests](https://www.zotero.org/support/dev/web_api/v3/write_requests)

**Capture**

- **Translation-server:** the official Docker image `zotero/translation-server` listens on port 1969.
  - `/web` takes a URL and returns Zotero JSON;
  - `/search` takes identifiers: DOI, ISBN, PMID, arXiv ID;
  - `/export?format=bibtex` and similar convert Zotero JSON;
  - the v1 `translation-server-old` repo is discontinued.
  — [translation-server repo (fork mirror)](https://github.com/adomasven/translation-server); [zotero-dev Nov 2025](https://groups.google.com/g/zotero-dev/c/vFZTymq3FcM); [issue #67](https://github.com/zotero/translation-server/issues/67)
- **Safari connector:** Zotero 10 shipped "an improved Safari connector". — [Zotero blog news](https://www.zotero.org/blog/category/news/)

**Better BibTeX**

- **JSON-RPC:** the endpoint is `http://localhost:23119/better-bibtex/json-rpc`. Methods:
  - `api.ready`;
  - `autoexport.add`;
  - `collection.scanAUX`;
  - `item.attachments` (by citekey);
  - `item.bibliography`;
  - `item.citationkey` (itemKey → citekey);
  - `item.collections`;
  - `item.export` (by citekeys + translator);
  - `item.notes`;
  - `item.pandoc_filter`;
  - `item.regenerate_key` (returns an old → new mapping);
  - `item.search`;
  - `user.groups`;
  - `viewer.viewPDF` (opens a PDF at a page).
  — [BBT JSON-RPC docs](https://retorque.re/zotero-better-bibtex/exporting/json-rpc/)
- **JSON-RPC history:** the `items.export` response format changed in 6.7.143, when a double-wrapping layer was removed. Clients should tolerate both shapes. — [search summary of BBT changelog](https://retorque.re/zotero-better-bibtex/changelog/index.html)
- **Version support:** BBT 9.x is strictly Zotero 8+. Zotero 8 now owns the citation-key field natively, and BBT keys were migrated into it. A forum report says `{{citationKey}}` no longer works as an export file-renaming token in Zotero 8. — [BBT changelog](https://retorque.re/zotero-better-bibtex/changelog/index.html); [Zettlr blog](https://zettlr.com/post/on-the-recent-issues-with-zotero-8-and-better-bibtex); [Zotero forum](https://forums.zotero.org/discussion/comment/507987)
- **Lessons from the Zotero 8 migration:** auto-exported CSL-JSON lost `id` fields during the disruption, and the disambiguation suffixes on citekeys (a/b) can swap when sort order changes. Tools depending on stable keys should re-verify them against current exports. — [Zettlr blog](https://zettlr.com/post/on-the-recent-issues-with-zotero-8-and-better-bibtex)

### Inferences
- **Recommended integration stack for a Swift app on Zotero 10:**
  1. Run `GET localhost:23119/api/users/0/items?since=<localVersion>&format=json&include=data,citation` for incremental sync, persisting `Zotero-Server-ID` and the local version.
  2. Fetch annotations as items: `itemType=annotation` children of attachments, with `annotationType`, `annotationText`, `annotationComment`, `annotationColor`, `annotationPageLabel`, `annotationPosition` and `tags`. The field names are standard Zotero JSON, but their documentation was not fetched here.
  3. Use `/items/<key>/file/view/url` to get the PDF path.
  4. Use `/fulltext` for the text cache.
  5. Optionally write back notes and tags with a one-time "Always Allow" local key.
- Use the Web API only for iOS or companion use, or when the Mac app must work without Zotero running. Its 50-object batches, 100-item pages and Backoff headers make it the slow path.
- **Citekeys:** read the native `citationKey` field (Zotero 8+) and treat BBT as optional. BBT JSON-RPC is still valuable for `item.bibliography`, `item.search` with BBT semantics, and pandoc workflows.
- **The translation-server** (Docker) is the cleanest way to reuse Zotero's ~600+ site translators headlessly. The translator count is general knowledge, not sourced here. However, running Docker is heavyweight for a personal Mac app. Alternatively, save via the running Zotero's connector endpoints. Their exact shape (e.g. `/connector/saveItems`) was not verified here.

### Gaps
- Connector server endpoints (`/connector/ping`, `/connector/saveItems`, `/connector/saveSnapshot`, `/connector/import`) were not documented in fetched sources.
- BBT pull-export URLs (`/better-bibtex/export/...`) and CAYW (`/better-bibtex/cayw`) were not confirmed. The JSON-RPC page only links a "Pull export" section.
- The Web API JSON field list for annotation items, and whether annotations can be created via the Web/local API, was not fetched. A 2026 forum feature request asks for an "API for programmatic PDF annotation creation", which suggests it is limited or awkward. — [Zotero forum](https://forums.zotero.org/discussion/132273/feature-request-expose-api-for-programmatic-pdf-annotation-creation-highlights-notes)
- The Web API's request-per-second numbers are not published. It is Backoff-driven.
- CSL style repository and citeproc options were not researched in depth (e.g. citeproc-js in JavaScriptCore vs citeproc-rs). Rendering through Zotero's `include=bib/citation&style=` avoids embedding citeproc altogether.

## 4. Sync: data vs file sync, storage tiers, WebDAV

### Takeaway
Data sync (metadata, notes, annotations) through zotero.org is free and unlimited. File sync uses Zotero Storage, which gives 300 MB free with paid tiers above that, or a user's own WebDAV.

### Cited Findings
- **Zotero Storage pricing:**

  | Plan | Price |
  |---|---|
  | Free | 300 MB |
  | 2 GB | $20/year |
  | 6 GB | $60/year |
  | Unlimited | $120/year |

  Lab and institution plans exist on a separate page. — [zotero.org/storage](https://www.zotero.org/storage)
- **Local API and sync:** changes made via the local API sync to zotero.org on the next sync if the library is synced. — [Local API docs](https://www.zotero.org/support/dev/web_api/v3/local_api)
- **Download-as-needed mode:** with "Sync full-text content", storage folders may contain only the full-text cache files, without the PDF. — [Zotero forum](https://forums.zotero.org/discussion/95839/folders-in-zotero-storage-with-only-hidden-files)

### Inferences
- A Mac app reading `storage/` must handle missing PDFs, which happens in download-as-needed mode. In that case, fall back to `.zotero-ft-cache` or trigger a download by opening the item in Zotero.
- For a personal setup, the realistic options are free data sync plus WebDAV, or the $20–$60 tier. The knowledge app should not duplicate PDFs into its own store unless it needs offline-independent parsing.

### Gaps
- The WebDAV setup details and the "data sync is unlimited/free" wording were not fetched from current Zotero docs. The sync support page (zotero.org/support/sync) was not retrieved. The storage page fetched does not mention WebDAV.
- No price change in 2026 was found. The prices above match long-standing figures.

## 5. Existing bridges: Obsidian, MCP servers, Markdown literature notes, plugins

### Takeaway
The most capable bridge in 2026 is **54yyyu/zotero-mcp**: MIT-licensed, about 5.8k stars, with 41 to 53 tools covering search, read, annotate, write, semantic search and Zotero 10 local writes. The Obsidian Zotero Integration plugin, the classic Zotero-to-Markdown path, appears stale (last release August 2024) and has user-reported failures on Zotero 8. ZotFile is dead: Attanger and Zotmoov are the successors for linked files.

### Cited Findings
- **zotero-mcp (54yyyu):**
  - **Access modes:** in local mode, reads come "straight from `zotero.sqlite`" and writes go through the running Zotero 10+ app after a one-time `zotero-mcp authorize-local`. In web mode, writes use `ZOTERO_API_KEY` and `ZOTERO_LIBRARY_ID`. A hybrid mode is also mentioned.
  - **Tools:** 41 in the default profile and 53 in total, configurable via `ZOTERO_MCP_TOOLSETS`.
  - **Capabilities:** add items by DOI, URL, ISBN, BibTeX or file (including open-access PDF fetching); manage collections and tags; merge duplicates; optional Scite citation data.
  - **Semantic search:** ChromaDB index using local, OpenAI, Gemini or Ollama embeddings, via `zotero-mcp update-db`.
  - **Annotations:** extraction of highlights, area boxes, notes and PDF annotations, with page numbers. The `pdf` extra (PyMuPDF) adds outlines, page images and EPUB annotations.
  - **Related tools:** a `zotero-cli` and an in-Zotero "Zotero Agent" chat panel.
  - **Popularity:** 5.8k stars, 456 forks.
  — [GitHub 54yyyu/zotero-mcp](https://github.com/54yyyu/zotero-mcp); [mcpservers.org](https://mcpservers.org/servers/54yyyu/zotero-mcp)
- **zotero-mcp latest release:** listing sites cite v0.6.1 (2026-07-03). The GitHub page fetched did not show releases, so this is unconfirmed. — [search summary of listing sites](https://www.sourcepulse.org/projects/2096818)
- **Other Zotero MCPs:** e.g. "zotero-keeper" (u9401066) appears in listings; not evaluated. — [lobehub](https://lobehub.com/mcp/u9401066-zotero-keeper)
- **Obsidian Zotero Integration (mgmeyers):**
  - requires Better BibTeX;
  - imports citations, bibliographies and PDF annotations into templated literature notes;
  - last release August 2024 (v3.2.1);
  - "documentation is currently incomplete";
  - one user reports "citation not found" for references added after the Zotero 8 switch on 2026-01-22, while running BBT 9.0.10. This is anecdotal and unconfirmed.
  — [GitHub](https://github.com/mgmeyers/obsidian-zotero-integration); [dsebastien notes](https://notes.dsebastien.net/30+Areas/33+Permanent+notes/33.02+Content/Zotero+Integration+plugin+for+Obsidian); [Obsidian forum](https://forum.obsidian.md/t/zotero-integration-and-citations/113012)
- **Other Obsidian bridges:** BibNotes Formatter is an alternative Obsidian plugin that keeps literature notes updated from Zotero "without the risk of losing the manual edits". — [Obsidian forum](https://forum.obsidian.md/t/bibnotes-formatter-new-plugin-to-export-and-format-annotations-from-zotero-into-obsidian/29920)
- **No two-way sync:** none of the Zotero↔Obsidian tools syncs annotations both ways; edits in Obsidian don't flow back. — [Obsidian forum](https://forum.obsidian.md/t/is-it-possible-an-obsidian-zotero-integration-that-sync-annotations-between-both-systems/48016)
- **ZotFile:** it does not run on Zotero 7+, and Zotero staff say it will not return. The successors Zotmoov (wileyyugioh/zotmoov) and Attanger (MuiseDestiny/zotero-attanger) manage *linked* files only and rely on Zotero's native renaming. Zotmoov added Send to Tablet (around December 2024). — [Zotero forum: Zotero 7 and Zotfile](https://forums.zotero.org/discussion/116679/zotero-7-and-zotfile)
- **Better Notes (windingwind):** a v3.0.0-beta.7 pre-release integrates with Zotero 8's native note tab. No stable Zotero 9 or 10 support statement was found. — [newreleases.io](https://newreleases.io/project/github/windingwind/zotero-better-notes/release/v3.0.0-beta.7)
- **Enhanced Notes (jsglazer):** declares Zotero 8–10.0.x support. — [GitHub releases](https://github.com/jsglazer/enhanced-notes/releases)

### Inferences
- zotero-mcp is the best existing reference implementation of "everything a client can do with Zotero 10". Its tool list is effectively a capability checklist for the Swift app's Zotero adapter. If the knowledge app exposes MCP or agent tooling, it could even delegate Zotero operations to it.
- The Obsidian literature-note path, which depends on BBT and templates, is fragile across Zotero's new cadence. A native app should not depend on BBT or Obsidian plugins. It should read annotations directly via the local API and render its own literature notes, keyed on Zotero item key plus annotation key, so the notes are idempotent and re-syncable.

### Gaps
- The full list of zotero-mcp tool names was not obtained.
- Last-release dates for Attanger, Zotmoov, Better Notes stable, PapersGPT and Beaver were not verified.
- Other MCP servers (e.g. kujenga/zotero-mcp, cookjohn's zotero-mcp plugin) were not checked.

## 6. Metadata enrichment and PDF-to-structure sources

### Takeaway
A custom app can enrich metadata from four main sources, each with new 2025–26 constraints:
- **Crossref:** new tiered rate limits since 2025-12-01; use the `mailto` polite pool.
- **OpenAlex:** an API key is now mandatory, with dollar-budgeted usage pricing: a free key gives $1/day, and DOI/ID lookups are reportedly free.
- **Semantic Scholar:** public shared pool; keys start at 1 RPS.
- **Zotero's translation-server:** for identifier lookup.

For PDF structure, GROBID remains the best at bibliographic metadata and references (TEI). Docling and Marker are better at full-document Markdown (tables, LaTeX).

### Cited Findings
- **Crossref limits, effective 2025-12-01** (announced 2025-11-05; the first change since 2013):

  | Pool | Request type | Rate | Concurrency |
  |---|---|---|---|
  | Public | Single-record | 5/s | 1 |
  | Public | List/query | 1/s | 1 |
  | Polite (via `mailto`) | Single-DOI | 10/s | 3 |
  | Polite (via `mailto`) | List | 3/s | 3 |

  The polite-pool list figure comes from mirrored copies and should be verified. Metadata Plus, the XML API and OAI-PMH are unaffected. — [Crossref blog](https://crossref.org/blog/announcing-changes-to-rest-api-rate-limits/); [Crossref community](https://community.crossref.org/t/announcing-changes-to-rest-api-rate-limits-crossref/14726)
- **OpenAlex:**
  - an API key is required for the hosted API since around Feb 2026 (sources give Feb 13 or late February);
  - free key: $1/day budget; no key: $0.01/day; 100 requests/second cap for everyone;
  - usage-based pricing per endpoint type, with list/filter calls at roughly $0.0001 each; singleton ID/DOI lookups reportedly free (secondary source);
  - `X-RateLimit-Remaining-USD` header and a `/rate-limit` endpoint report usage.
  — [OpenAlex developer docs: authentication](https://developers.openalex.org/api-reference/authentication); [openalex-users group](https://groups.google.com/g/openalex-users/c/rI1GIAySpVQ); [CASRAI](https://casrai.org/news/openalex-api-keys-mandatory-usage-based-pricing-2026). Third-party figures conflict (credits vs dollars), so check official pricing.
- **Semantic Scholar:**
  - unauthenticated use is a shared pool, described as "1000 requests per second shared among all unauthenticated users";
  - API keys (sent in the `x-api-key` header) start at 1 RPS, with higher rates granted after review;
  - heavy users are told to download the datasets;
  - a tutorial mirror instead says 5,000 requests per 5 minutes unauthenticated (conflicting).
  — [Semantic Scholar API overview](https://semanticscholar.org/product/api); [S2 tutorial](https://webflow.semanticscholar.org/product/api/tutorial)
- **GROBID:**
  - an older benchmark found GROBID best at metadata and reference extraction, ahead of CERMINE and Science Parse;
  - in an informal 10-paper test, GROBID was much faster than Docling;
  - GROBID outputs TEI XML (header, references), unlike general converters.
  — [PDF extraction benchmark](https://cs.paperswithcode.com/paper/a-benchmark-of-pdf-information-extraction); [Docling discussion #622](https://github.com/docling-project/docling/discussions/622)
- **Docling vs Marker:**
  - Marker leads on inline LaTeX; tables are roughly tied;
  - Marker is CPU-slow (about 4.5 minutes for an arXiv paper on a CPX31);
  - a Docling-using vendor reports Marker at 6.1 pages/s vs Docling at 3.2 pages/s, with Docling better on tables and Marker better on multi-column layout (vendor bias).
  — [dev.to comparison](https://dev.to/dmaxdev/markitdown-vs-docling-vs-marker-pdf-to-markdown-for-llms-571o); [Ertas benchmark](https://www.ertas.ai/blog/pdf-parsing-accuracy-benchmark-docling-unstructured)

### Inferences
- **Enrichment cascade for a personal app:**
  1. Take the DOI from Zotero metadata (or extract it with GROBID).
  2. Get the canonical record from Crossref (polite pool, single-DOI path, 10/s is ample for personal use).
  3. Get concepts/topics, open-access location and reference/citation graph from OpenAlex. Singleton lookups are cheap; avoid list queries to stay under budget.
  4. Get TLDRs, embeddings, citation contexts and recommendations from Semantic Scholar. Request a key, because the public pool is contended.
  5. Use arXiv for preprint versions.
  6. Use Unpaywall for OA PDF URLs; OpenAlex's OA data covers much of this.
- **PDF structure:** a personal Mac app can call GROBID (Docker, Java) once per paper for references and sections, and Docling or Marker (Python) for Markdown chunks to embed. Or start from Zotero's `.zotero-ft-cache` plain text for search, and only run heavier parsers on papers being actively studied.

### Gaps
- The arXiv API (export.arxiv.org rate guidance of about 1 request every 3 seconds; OAI-PMH) and Unpaywall (email parameter, roughly 100k calls/day) were not fetched. Those figures come from training knowledge and need verification.
- Nougat's maintenance status in 2026 was not checked; it was believed largely unmaintained since 2024 (unverified). Marker's and Docling's licences were not checked; Marker's model weights historically had commercial restrictions, which is irrelevant for personal use.
- No 2026 head-to-head of GROBID, Docling and Marker on scientific papers was found.
- Apple-native options (PDFKit text extraction, the Vision framework's document-recognition APIs introduced in 2025) were not researched; these belong to another researcher's scope.

## 7. Practitioner verdicts: Zotero as source of record vs dead end, and the split of responsibilities

### Takeaway
The consensus pattern: Zotero is the system of record for references, PDFs, highlights and citations, and a separate note app is where synthesis and linking happen. The pain point is not capture but one-way, siloed annotations. Extraction to Markdown works, but there is no two-way sync, and Zotero notes have weak idea-level linking. Zotero 10's annotation search and AI plugins narrow the gap without closing it.

### Cited Findings
- **Common split:** "Zotero stays the place for storing papers and highlights", while Obsidian becomes the place for plain-text notes, links and long-term knowledge building. — [search summary of skillselion guide](https://skillselion.com/skills/wentorai/research-plugins/obsidian-zotero-guide); see also [USU groundwater blog: A Zotero to Obsidian workflow](https://groundwater.usu.edu/blog/2023/A-Zotero-to-Obsidian-Workflow/)
- **Synthesis as the critical step:** a researcher calls synthesis the most critical part of the workflow and says collecting sources with nothing done to them is wasteful. They note Zotero notes could host this, but chose Obsidian. — [Medium: Alexandra Phelan](https://medium.com/@alexandraphelan/an-academic-workflow-zotero-obsidian-56bf918d51ab)
- **No two-way sync:** existing Zotero↔Obsidian tools are not capable of syncing annotation edits back to Zotero. — [Obsidian forum](https://forum.obsidian.md/t/is-it-possible-an-obsidian-zotero-integration-that-sync-annotations-between-both-systems/48016)
- **Zotero improving on retrieval:** Zotero 10 adds annotation conditions in advanced search, Zotero 9 adds "Add Annotation" into Word/LibreOffice with live citations, and Zotero 8 has a native note tab, which Better Notes integrates with. — [Zotero blog news](https://www.zotero.org/blog/category/news/); [Better Notes beta](https://newreleases.io/project/github/windingwind/zotero-better-notes/release/v3.0.0-beta.7)

### Inferences
- **Recommended split for the Swift knowledge app:**
  - **Zotero owns:** capture (Connector, translators, DOI/ISBN import), canonical bibliographic metadata, citekeys, PDF/EPUB storage and sync, reading and annotation on Mac, iOS and Android, citation insertion into Word or Google Docs, and CSL bibliography rendering.
  - **The knowledge app owns:**
    - claim and concept notes with bidirectional links;
    - annotation-to-idea linking, where each Zotero annotation key becomes a quotable, linkable block;
    - cross-paper synthesis and AI (embeddings, Q&A, contradiction finding);
    - spaced review;
    - enrichment beyond Zotero (OpenAlex concepts, S2 citation context);
    - structured full-text parsing (GROBID, Docling).
  - **Integration contract:**
    - the knowledge app references papers by `zotero://select/library/items/<KEY>` and annotations by key, using `zotero://open-pdf/library/items/<KEY>?page=&annotation=` deep links. These URL schemes are general Zotero knowledge and were not verified in this research;
    - incremental pull runs via the local API's `?since=`;
    - write-back is limited to tags and child notes (e.g. a "synthesized" tag, or a backlink note) using a Zotero 10 local key.
- **Replace Zotero only if** the user doesn't need citations in a word processor, doesn't use mobile annotation, and is willing to rebuild capture. Otherwise replacement is a poor trade, because Zotero's translators, sync and readers are years of work and free.
- **Main risk:** Zotero's fast cadence. Pin to the HTTP API's documented behaviour, check the `Zotero-API-Version` and `Zotero-Schema-Version` headers, and keep a SQLite-copy fallback.

### Gaps
- No high-quality, recent (2026) practitioner survey or forum thread explicitly calling Zotero a "dead end" was found. The verdicts above come from workflow blog posts and forum requests, so they are directional.
- Not researched: how users rate Zotero 10's search and annotation features for synthesis, and whether AI plugins like Beaver have changed practitioner habits.

## 8. Licensing: AGPL implications

### Takeaway
Zotero is AGPL-3.0. A separate personal app that reads Zotero data over the HTTP APIs or from data files does not incorporate Zotero code, and personal non-distributed use triggers no AGPL source-distribution obligations in any case. AGPL concerns arise mainly for code that runs inside Zotero (plugins), forks, or closed services built on Zotero code. Zotero staff have challenged at least one closed, subscription-based tool built on Zotero.

### Cited Findings
- **Closed tool challenged:** Zotero staff said a closed, subscription-based tool built on Zotero ("vibero") violates the AGPL and that they contacted its developers. A commenter noted that pairing a FLOSS Zotero fork with a closed, paid AI server may be allowed, so the boundary depends on architecture. — [Zotero forum: vibero AGPL](https://forums.zotero.org/discussion/comment/509691)
- **Plugins:** whether plugins must be AGPL is unsettled in forum discussion; one commenter sees no sign that Zotero argues its licence applies to plugins. Several plugins are voluntarily AGPL-3.0 (e.g. llm-for-zotero, Zotero Tab Manager). — [Zotero forum: plugin AGPL](https://forums.zotero.org/discussion/comment/495195/); [rg4sun/zotero-tab-manager](https://github.com/rg4sun/zotero-tab-manager/releases); [dev.co: llm-for-zotero](https://dev.co/ai/rag/llm-for-zotero)
- **Obfuscated plugin builds:** distributing obfuscated builds of AGPL plugins without Corresponding Source was flagged as non-compliant with AGPL §6. — [Zotero forum](https://forums.zotero.org/discussion/comment/507862)
- **Licences of the bridges:** 54yyyu/zotero-mcp is MIT-licensed. — [GitHub](https://github.com/54yyyu/zotero-mcp)

### Inferences
- For a personal-use Swift app that talks to Zotero over `localhost:23119` or the Web API, or reads a copied `zotero.sqlite`, AGPL is effectively a non-issue. It is a separate program communicating over documented interfaces and is not distributed.
- If the app is ever distributed, the safe boundary is: don't bundle or port Zotero source (e.g. translators, the reader, schema-handling JS) into the app. Translators in `zotero/translators` are also AGPL. Running them via a separate translation-server process keeps them at arm's length.
- CSL styles are CC BY-SA (general knowledge, not verified here), so bundling styles needs attribution.

### Gaps
- No authoritative legal statement from Zotero on external apps reading its DB or APIs was found. Licences were not verified for zotero/translators, CSL styles and the translation-server.
