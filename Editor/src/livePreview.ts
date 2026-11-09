import { syntaxTree } from "@codemirror/language";
import { type EditorState, Facet, type Range, StateEffect, StateField } from "@codemirror/state";
import { Decoration, type DecorationSet, EditorView, ViewPlugin, type ViewUpdate, WidgetType } from "@codemirror/view";
import type { EmbedKind } from "./bridge";
import { linkKey } from "./wikilink";

/** What an embed shows. `text` for notes, `dataURL` for images. */
export interface EmbedContent {
  kind: EmbedKind;
  title?: string;
  text?: string;
  dataURL?: string;
}

/** How embed widgets fetch content (the editor asks the host). Cached per target. */
export const embedResolver = Facet.define<(target: string) => Promise<EmbedContent>, ((target: string) => Promise<EmbedContent>) | null>({
  combine: (values) => values[0] ?? null,
});

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
  | { kind: "line"; from: number; className: string }
  /** Replaces a range with a widget: a callout's type label, or an embed's content. */
  | { kind: "widget"; from: number; to: number; widget: "callout" | "embed"; data: string };

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
          const last = state.doc.lineAt(node.to).number;
          const callout = /^(>\s*)(\[!([\w-]+)\][+-]?\s?)/.exec(line.text);
          for (let number = line.number; number <= last; number++) {
            const className = callout
              ? `${number === line.number ? "cm-callout cm-callout-title" : "cm-callout"} cm-callout-${callout[3]!.toLowerCase()}`
              : "cm-quote";
            specs.push({ kind: "line", from: state.doc.line(number).from, className });
          }
          if (callout && !isActive(line.from)) {
            const start = line.from + callout[1]!.length;
            specs.push({ kind: "widget", from: start, to: start + callout[2]!.length, widget: "callout",
                         data: callout[3]!.toLowerCase() });
          }
          return;
        }
        if (name === "QuoteMark") {
          if (!isActive(node.from)) {
            const end = state.sliceDoc(node.to, node.to + 1) === " " ? node.to + 1 : node.to;
            specs.push({ kind: "hide", from: node.from, to: end });
          }
          return false;
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
          // Attachments (images, PDFs) aren't notes, so they never count as unresolved links.
          const isAttachment = /\.[a-z0-9]{2,5}$/i.test(key) && !key.endsWith(".md");
          const unresolved = resolved !== null && key !== "" && !isAttachment && !resolved.has(key);
          const className = [name === "Embed" ? "cm-embed" : "cm-wikilink", unresolved ? "cm-unresolved" : ""]
            .filter(Boolean)
            .join(" ");
          if (name === "Embed" && !lineActive && raw) {
            specs.push({ kind: "widget", from: node.from, to: node.to, widget: "embed", data: raw });
            return false;
          }
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

const CALLOUT_ICONS: Record<string, string> = {
  note: "✎", info: "ℹ", tip: "★", warning: "⚠", danger: "⚡", question: "?", quote: "❝", prompt: "◆", example: "▸",
};

class CalloutLabel extends WidgetType {
  constructor(readonly type: string) {
    super();
  }
  override eq(other: CalloutLabel) {
    return other.type === this.type;
  }
  toDOM() {
    const element = document.createElement("span");
    element.className = `cm-callout-label cm-callout-label-${this.type}`;
    element.textContent = `${CALLOUT_ICONS[this.type] ?? "•"} ${this.type.charAt(0).toUpperCase()}${this.type.slice(1)}`;
    return element;
  }
}

class EmbedWidget extends WidgetType {
  constructor(readonly target: string) {
    super();
  }
  override eq(other: EmbedWidget) {
    return other.target === this.target;
  }
  toDOM(view: EditorView) {
    const element = document.createElement("span");
    element.className = "cm-embed-box";
    element.textContent = `↳ ${this.target}`;
    const resolve = view.state.facet(embedResolver);
    if (resolve) {
      void resolve(this.target).then((content) => render(element, this.target, content));
    }
    return element;
  }
  override ignoreEvent() {
    return false;
  }
}

function render(element: HTMLElement, target: string, content: EmbedContent) {
  element.replaceChildren();
  if (content.kind === "image" && content.dataURL) {
    const image = document.createElement("img");
    image.src = content.dataURL;
    image.alt = target;
    image.className = "cm-embed-image";
    element.appendChild(image);
  } else if (content.kind === "note") {
    const title = document.createElement("span");
    title.className = "cm-embed-title";
    title.textContent = content.title ?? target;
    const body = document.createElement("span");
    body.className = "cm-embed-text";
    body.textContent = content.text ?? "";
    element.append(title, body);
  } else {
    element.classList.add("cm-embed-missing");
    element.textContent = `↳ ${target} (not found)`;
  }
}

function toDecorationSet(specs: DecorationSpec[]): DecorationSet {
  const ranges: Range<Decoration>[] = [];
  for (const spec of specs) {
    if (spec.kind === "hide") ranges.push(Decoration.replace({}).range(spec.from, spec.to));
    else if (spec.kind === "mark") {
      ranges.push(Decoration.mark({ class: spec.className, attributes: spec.attributes }).range(spec.from, spec.to));
    } else if (spec.kind === "widget") {
      const widget = spec.widget === "callout" ? new CalloutLabel(spec.data) : new EmbedWidget(spec.data);
      ranges.push(Decoration.replace({ widget }).range(spec.from, spec.to));
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
