# Spec: KBCore (vault model, parser, policy, safe writer)

Status: **built** (phase 0, 2026-11-09). Plan refs: §2 principles 1–3, 7, 9; §4.3–4.5; §13 day 8.

## Inputs
- Raw bytes of one Markdown file plus its vault-relative path.
- `.granite/policy.yaml` (optional; the built-in policy applies when absent).

## Outputs
- `ParsedNote`: title (file stem), `id`, `type`, `kind`, `origin`, `aiLabel`, `status`, `created`, aliases, frontmatter (raw YAML, ordered properties, parse error), tags, links, blocks, size, SHA-256.
- `VaultPolicy.policy(for:)`: longest-prefix folder rule (`ai`, `origin`, `agents`, `managed`, `trust`, `mcp: hidden`, `evidence`).
- `SafeWriter.write(_:to:as:)`: coordinated atomic write; `isEcho(path:hash:)` for watcher echo suppression.
- `FrontmatterEditor.setScalar`: one-line frontmatter edit (for lazy `id` stamping).
- `ULID`, `Vault.markdownFiles()`, `Vault.supportDirectory`.

## Rules (tested)
| Area | Behaviour |
|---|---|
| Frontmatter | Opens with `---` on line 1 (BOM allowed), closes with `---` or `...`. No closing fence: whole file is body. Bad YAML: properties ignored, `error` set, body still indexed. Timestamps stay as written. |
| Line endings | Split on bytes, so CRLF works (Swift treats `\r\n` as one Character). |
| Links | `[[t]]`, `[[t\|alias]]`, `[[t#Heading]]`, `[[t#^block]]`, `[[#Heading]]` (self), `![[embed]]`, `[x](rel/path.md#Part)`, `[x](<With Spaces.md>)`. URLs, `mailto:`, `zotero:`, non-`.md` files are not note links. Markdown-link targets are rewritten vault-relative. `\[[` escapes. |
| Typed relations | Frontmatter lists for `supports`, `contradicts`, `supersedes`, `derived_from`, `implemented_in`, `about`, `source`; quoted wikilinks or bare names. |
| Tags | Frontmatter `tags`/`tag` (list or comma string, `#` optional) + inline `#tag` at a word boundary; letters, digits, `_ - /`; at least one non-digit; deduped case-insensitively. |
| Not scanned | Fenced code (``` and ~~~), `$$` math, inline code, `%% comments %%`, HTML comment lines. |
| Blocks | heading, paragraph, list item (with continuation lines), quote, callout (`> [!type]`), table, code, math. Trailing ` ^id` or a following `^id` line names the block. Heading paths are `A > B`. |
| Origin | Frontmatter `origin`, else folder default. A folder whose origin is `ai` forces `ai`. |
| AI label | Strictest of folder label and the note's `ai:`; a note can tighten, never loosen. Unknown folders fall back to `local` (fail closed). |
| Writes | `.ai` role: only `AI/<something>`. Nobody writes `.obsidian/`, `.git/`, absolute paths or `..`. Frontmatter edits refuse YAML that does not parse. |

## Files
`Packages/KBCore/Sources/KBCore/{Types,ULID,Lines,Frontmatter,InlineScanner,BlockParser,NoteParser,Policy,Vault,SafeWriter}.swift`; tests and golden notes in `Packages/KBCore/Tests/KBCoreTests/`.

## Done when
- [x] `swift test` green (29 tests) on 12 golden edge-case notes.
- [x] Stamping an `id` changes one line (or adds a 3-line block) and nothing else, byte-for-byte.
- [ ] Golden set grows to ~30 notes from real Obsidian exports (plan §13 day 8 target).

## Not yet
Setext headings; inline `%%comments%%` inside a line; Obsidian's `[[folder/partial]]` ambiguity rules beyond suffix match; symlink escape checks in `SafeWriter`.
