import type { InlineContext, MarkdownConfig } from "@lezer/markdown";

// Obsidian syntax as Lezer inline nodes, so it lives in the syntax tree next to CommonMark:
//   [[target#anchor|alias]]   → WikiLink (WikiLinkMark, WikiLinkTarget, WikiLinkAlias)
//   ![[target]]               → Embed    (same children)
//   #tag                      → Tag
//   ^block-id at line end     → BlockID

const OPEN = 91; // [
const CLOSE = 93; // ]
const BANG = 33; // !
const HASH = 35; // #
const CARET = 94; // ^
const PIPE = 124; // |
const NEWLINE = 10;

function isTagChar(code: number): boolean {
  if (code < 0) return false;
  const char = String.fromCodePoint(code);
  return /[\p{L}\p{N}_\-/]/u.test(char);
}

function parseLink(cx: InlineContext, start: number, open: number, node: "WikiLink" | "Embed"): number {
  // `open` is the position of the first "[".
  let pos = open + 2;
  let pipe = -1;
  while (pos + 1 < cx.end) {
    const code = cx.char(pos);
    if (code === NEWLINE) return -1;
    if (code === OPEN && cx.char(pos + 1) === OPEN) return -1;
    if (code === CLOSE && cx.char(pos + 1) === CLOSE) break;
    if (code === PIPE && pipe < 0 && cx.char(pos - 1) !== 92) pipe = pos;
    pos++;
  }
  if (pos + 1 >= cx.end || pos === open + 2) return -1;
  const close = pos;
  const children = [cx.elt("WikiLinkMark", start, open + 2)];
  if (pipe >= 0) {
    children.push(cx.elt("WikiLinkTarget", open + 2, pipe));
    children.push(cx.elt("WikiLinkMark", pipe, pipe + 1));
    children.push(cx.elt("WikiLinkAlias", pipe + 1, close));
  } else {
    children.push(cx.elt("WikiLinkTarget", open + 2, close));
  }
  children.push(cx.elt("WikiLinkMark", close, close + 2));
  return cx.addElement(cx.elt(node, start, close + 2, children));
}

export const obsidianSyntax: MarkdownConfig = {
  defineNodes: [
    { name: "WikiLink" },
    { name: "Embed" },
    { name: "WikiLinkMark" },
    { name: "WikiLinkTarget" },
    { name: "WikiLinkAlias" },
    { name: "Tag" },
    { name: "BlockID" },
  ],
  parseInline: [
    {
      name: "WikiLink",
      before: "Link",
      parse(cx, next, pos) {
        if (next === OPEN && cx.char(pos + 1) === OPEN) return parseLink(cx, pos, pos, "WikiLink");
        if (next === BANG && cx.char(pos + 1) === OPEN && cx.char(pos + 2) === OPEN) {
          return parseLink(cx, pos, pos + 1, "Embed");
        }
        return -1;
      },
    },
    {
      name: "Tag",
      parse(cx, next, pos) {
        if (next !== HASH) return -1;
        const before = pos > cx.offset ? cx.char(pos - 1) : 32;
        if (!(before === 32 || before === 9 || pos === cx.offset)) return -1;
        let end = pos + 1;
        let nonDigit = false;
        while (end < cx.end && isTagChar(cx.char(end))) {
          if (!/\p{N}/u.test(String.fromCodePoint(cx.char(end)))) nonDigit = true;
          end++;
        }
        if (end === pos + 1 || !nonDigit) return -1;
        return cx.addElement(cx.elt("Tag", pos, end));
      },
    },
    {
      name: "BlockID",
      parse(cx, next, pos) {
        if (next !== CARET) return -1;
        if (pos === cx.offset || cx.char(pos - 1) !== 32) return -1;
        let end = pos + 1;
        while (end < cx.end && /[A-Za-z0-9-]/.test(String.fromCharCode(cx.char(end)))) end++;
        if (end === pos + 1) return -1;
        // Only at the end of the line (trailing spaces allowed).
        let rest = end;
        while (rest < cx.end && cx.char(rest) === 32) rest++;
        if (rest < cx.end && cx.char(rest) !== NEWLINE) return -1;
        return cx.addElement(cx.elt("BlockID", pos, end));
      },
    },
  ],
};

/** Lowercased lookup key, matching KBCore's `LinkRef.key(for:)`. */
export function linkKey(target: string): string {
  let key = target.trim();
  const hash = key.indexOf("#");
  if (hash >= 0) key = key.slice(0, hash);
  if (key.toLowerCase().endsWith(".md")) key = key.slice(0, -3);
  return key.toLowerCase();
}

export interface ParsedTarget {
  target: string;
  heading?: string;
  blockID?: string;
}

/** Splits `target#Heading` / `target#^block` the way KBCore does. */
export function parseTarget(raw: string): ParsedTarget {
  const hash = raw.indexOf("#");
  if (hash < 0) return { target: raw.trim() };
  const target = raw.slice(0, hash).trim();
  const anchor = raw.slice(hash + 1);
  if (anchor.startsWith("^")) return { target, blockID: anchor.slice(1) };
  const parts = anchor.split("#");
  const heading = parts[parts.length - 1];
  return heading ? { target, heading } : { target };
}
