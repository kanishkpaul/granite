# Spec: web clipper

Status: **built**. Plan refs: §4.3 (`Clippings/`, raw web layer), §6.6 (prompt-injection defenses at clip time), §8 phase 4.

## Inputs
- A URL: ⌘K "Clip a web page…" (prefilled from the clipboard), or `granite://clip?url=…&why=…` from any app; as a bookmarklet: `javascript:location.href='granite://clip?url='+encodeURIComponent(location.href)`.

## Outputs
- `Clippings/<title>.md`: `type: clipping`, `origin: source`, `trust: untrusted`, `title`, `source` (URL), `author`, `published`, `site`, `clipped`, optional `why`; the description as a quote; the article as Markdown (tables, code, math as LaTeX).

## How
- A hidden `WKWebView` with a non-persistent data store (no cookies or storage kept) loads the page (30 s limit), waits for rendering, then runs `App/Resources/editor/clipper.js` (Defuddle 0.19.6 plus a sanitizer, built from `Editor/src/clipper.ts`) in its own content world, which the page's scripts can't see or alter.
- Sanitizing happens twice (in the page and in Swift): hidden elements removed, HTML comments, zero-width and bidi characters stripped, `[[` escaped so a clipping can't link into the vault, a `---` line can't fake frontmatter.
- Only http and https URLs; the page is never given a message handler into granite.

## Files
`Editor/src/clipper.ts`, `Editor/vite.clipper.config.ts`, `Packages/KBCapture/Sources/KBCapture/Clipping.swift`, `KBCapture.GraniteURL` (`clip`), `App/Clipper/WebClipper.swift`; tests `clipper.test.ts`, `ClippingTests`, `CaptureTests` (URLs).

## Done when
- [x] Tests above; a live Wikipedia article clipped through the app (1,243 words, metadata, math).
- [ ] A bookmarklet in your browser (you).
