import Defuddle from "defuddle/full";

// The web clipper (master plan §6.6): runs inside the page in an isolated content world, extracts
// the main content as Markdown with Defuddle, and strips what could hide instructions.

export interface Clip {
  title: string;
  author: string;
  published: string;
  site: string;
  description: string;
  markdown: string;
  wordCount: number;
}

/** Zero-width, bidi-control and other invisible characters used to hide text from a reader. */
const INVISIBLE = /[​-‏‪-‮⁠-⁤⁦-⁩﻿­]/g;

export function sanitize(markdown: string): string {
  return markdown
    .replace(/<!--[\s\S]*?-->/g, "")
    .replace(INVISIBLE, "")
    // A clipping must not create links into the vault.
    .replace(/\[\[/g, "[\\[")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

export function clip(url: string): Clip {
  const result = new Defuddle(document, { url, markdown: true, useAsync: false, removeHiddenElements: true }).parse();
  const clean = (text: string | undefined) => (text ?? "").replace(INVISIBLE, "").trim();
  return {
    title: clean(result.title) || document.title || url,
    author: clean(result.author),
    published: clean(result.published),
    site: clean(result.site || result.domain),
    description: clean(result.description),
    markdown: sanitize(result.content ?? ""),
    wordCount: result.wordCount ?? 0,
  };
}

(globalThis as unknown as { graniteClip: typeof clip }).graniteClip = clip;
