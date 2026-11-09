import { syntaxTree } from "@codemirror/language";
import { type EditorState, type Range, StateEffect, StateField } from "@codemirror/state";
import { Decoration, type DecorationSet, EditorView, ViewPlugin, type ViewUpdate } from "@codemirror/view";
import { linkKey } from "./wikilink";

// Obsidian-style live preview: Markdown syntax marks are hidden except on lines the selection
// touches, headings and links are styled in place. Only visible ranges are decorated.

/** Link keys (lowercased, no ".md") that resolve to a note. Set by the host. */
export const setResolvedEffect = StateEffect.define<ReadonlySet<string>>();

export const resolvedTargets = StateField.define<ReadonlySet<string> | null>({
  create: () => null,
  update(value, transaction) {
    for (const effect of transaction.effects) if (effect.is(setResolvedEffect)) return effect.value;
    return value;
  },
});

/** A decoration as plain data, so the logic is testable without a DOM. */
export type DecorationSpec =
  | { kind: "hide"; from: number; to: number }
  | { kind: "mark"; from: number; to: number; className: string; attributes?: Record<string, string> }
  | { kind: "line"; from: number; className: string };

const HIDDEN_MARKS = new Set(["HeaderMark", "EmphasisMark", "CodeMark", "StrikethroughMark"]);
const MARK_CLASSES: Record<string, string> = {
  Emphasis: "cm-em",
  StrongEmphasis: "cm-strong",
  Strikethrough: "cm-strike",
  InlineCode: "cm-inline-code",
  Tag: "cm-tag",
  BlockID: "cm-block-id",
  URL: "cm-url",
};

function activeLines(state: EditorState): Set<number> {
  const lines = new Set<number>();
  for (const range of state.selection.ranges) {
    const first = state.doc.lineAt(range.from).number;
    const last = state.doc.lineAt(range.to).number;
    for (let line = first; line <= last; line++) lines.add(line);
  }
  return lines;
}

/** Computes live-preview decorations for the given document ranges. */
export function computeDecorations(
  state: EditorState,
  ranges: readonly { from: number; to: number }[] = [{ from: 0, to: state.doc.length }],
): DecorationSpec[] {
  const specs: DecorationSpec[] = [];
  const active = activeLines(state);
  const resolved = state.field(resolvedTargets, false) ?? null;
  const tree = syntaxTree(state);
  const isActive = (pos: number) => active.has(state.doc.lineAt(pos).number);

  for (const { from, to } of ranges) {
    tree.iterate({
      from,
      to,
      enter(node) {
        const name = node.name;
        const heading = /^ATXHeading([1-6])$/.exec(name);
        if (heading) {
          specs.push({ kind: "line", from: node.from, className: `cm-heading cm-h${heading[1]}` });
          return;
        }
        if (name === "Blockquote") {
          const line = state.doc.lineAt(node.from);
          const callout = /^>\s*\[!([\w-]+)\]/.exec(line.text);
          if (callout) {
            const last = state.doc.lineAt(node.to).number;
            for (let number = line.number; number <= last; number++) {
              const className = number === line.number ? "cm-callout cm-callout-title" : "cm-callout";
              specs.push({ kind: "line", from: state.doc.line(number).from, className: `${className} cm-callout-${callout[1]!.toLowerCase()}` });
            }
          }
          return;
        }
        if (name === "FencedCode") {
          const first = state.doc.lineAt(node.from).number;
          const last = state.doc.lineAt(node.to).number;
          for (let number = first; number <= last; number++) {
            specs.push({ kind: "line", from: state.doc.line(number).from, className: "cm-code-block" });
          }
          return false;
        }
        if (name === "WikiLink" || name === "Embed") {
          const lineActive = isActive(node.from);
          const targetNode = node.node.getChild("WikiLinkTarget");
          const aliasNode = node.node.getChild("WikiLinkAlias");
          const raw = targetNode ? state.sliceDoc(targetNode.from, targetNode.to) : "";
          const key = linkKey(raw);
          const unresolved = resolved !== null && key !== "" && !resolved.has(key);
          const className = [name === "Embed" ? "cm-embed" : "cm-wikilink", unresolved ? "cm-unresolved" : ""]
            .filter(Boolean)
            .join(" ");
          const visibleFrom = !lineActive && aliasNode ? aliasNode.from : (targetNode?.from ?? node.from);
          const visibleTo = aliasNode && !lineActive ? aliasNode.to : (targetNode?.to ?? node.to);
          if (!lineActive) {
            if (visibleFrom > node.from) specs.push({ kind: "hide", from: node.from, to: visibleFrom });
            if (visibleTo < node.to) specs.push({ kind: "hide", from: visibleTo, to: node.to });
          }
          if (visibleTo > visibleFrom) {
            specs.push({ kind: "mark", from: visibleFrom, to: visibleTo, className, attributes: { "data-target": raw } });
          }
          return false;
        }
        const markClass = MARK_CLASSES[name];
        if (markClass) specs.push({ kind: "mark", from: node.from, to: node.to, className: markClass });
        if (HIDDEN_MARKS.has(name) && !isActive(node.from)) {
          // Keep the space after "#" hidden too, so headings start flush.
          let end = node.to;
          if (name === "HeaderMark" && state.sliceDoc(end, end + 1) === " ") end += 1;
          if (end > node.from) specs.push({ kind: "hide", from: node.from, to: end });
        }
        return undefined;
      },
    });
  }
  return specs;
}

function toDecorationSet(specs: DecorationSpec[]): DecorationSet {
  const ranges: Range<Decoration>[] = [];
  for (const spec of specs) {
    if (spec.kind === "hide") ranges.push(Decoration.replace({}).range(spec.from, spec.to));
    else if (spec.kind === "mark") {
      ranges.push(Decoration.mark({ class: spec.className, attributes: spec.attributes }).range(spec.from, spec.to));
    } else ranges.push(Decoration.line({ class: spec.className }).range(spec.from));
  }
  return Decoration.set(ranges, true);
}

export const livePreview = ViewPlugin.fromClass(
  class {
    decorations: DecorationSet;

    constructor(view: EditorView) {
      this.decorations = toDecorationSet(computeDecorations(view.state, view.visibleRanges));
    }

    update(update: ViewUpdate) {
      const resolvedChanged = update.transactions.some((tr) => tr.effects.some((e) => e.is(setResolvedEffect)));
      if (
        update.docChanged ||
        update.viewportChanged ||
        update.selectionSet ||
        resolvedChanged ||
        syntaxTree(update.startState) !== syntaxTree(update.state)
      ) {
        this.decorations = toDecorationSet(computeDecorations(update.state, update.view.visibleRanges));
      }
    }
  },
  { decorations: (plugin) => plugin.decorations },
);
