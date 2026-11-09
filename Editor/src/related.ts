import { syntaxTree } from "@codemirror/language";
import { type ChangeSpec, type EditorState, StateEffect, StateField } from "@codemirror/state";
import { Decoration, type DecorationSet, EditorView, WidgetType } from "@codemirror/view";
import type { RelatedItem } from "./bridge";
import { frontmatterRange } from "./frontmatter";

// Inline related items (master plan §7, idea 2): while you write, up to three related notes appear
// as ghost links at the end of the paragraph you are in. Clicking one inserts a real link; × hides it.

/** Fewer words than this and the paragraph says too little to find related notes. */
export const MIN_WORDS = 8;
export const MAX_ITEMS = 3;

export interface Paragraph {
  from: number;
  to: number;
  text: string;
}

/** The paragraph around `pos`: neighbouring non-blank lines, stopping at headings. Null in
 *  frontmatter, code, or on a heading line. */
export function paragraphAt(state: EditorState, pos: number): Paragraph | null {
  const yaml = frontmatterRange(state);
  if (yaml && pos <= yaml.to) return null;
  const node = syntaxTree(state).resolveInner(pos, -1);
  for (let n: typeof node | null = node; n; n = n.parent) {
    if (n.name === "FencedCode" || n.name === "CodeBlock" || n.name.startsWith("ATXHeading")) return null;
  }
  const doc = state.doc;
  const isBreak = (text: string) => text.trim() === "" || /^#{1,6}\s/.test(text) || /^(```|~~~)/.test(text.trim());
  const here = doc.lineAt(pos);
  if (isBreak(here.text)) return null;
  let first = here.number;
  let last = here.number;
  while (first > 1 && !isBreak(doc.line(first - 1).text) && (!yaml || doc.line(first - 1).from > yaml.to)) first--;
  while (last < doc.lines && !isBreak(doc.line(last + 1).text)) last++;
  const from = doc.line(first).from;
  const to = doc.line(last).to;
  return { from, to, text: state.sliceDoc(from, to) };
}

export function wordCount(text: string): number {
  return text.split(/\s+/).filter((word) => /[\p{L}\p{N}]/u.test(word)).length;
}

/** The edit that accepting `item` makes: a mention becomes a link in place; otherwise the link
 *  is appended to the paragraph. Null if a mention can no longer be found. */
export function acceptChange(state: EditorState, paragraph: { from: number; to: number }, item: RelatedItem): ChangeSpec | null {
  const link = (shown?: string) =>
    shown && shown.toLowerCase() !== item.title.toLowerCase() ? `[[${item.title}|${shown}]]` : `[[${item.title}]]`;
  if (item.mention) {
    const text = state.sliceDoc(paragraph.from, paragraph.to);
    const index = text.toLowerCase().indexOf(item.mention.toLowerCase());
    if (index >= 0) {
      const shown = text.slice(index, index + item.mention.length);
      return { from: paragraph.from + index, to: paragraph.from + index + item.mention.length, insert: link(shown) };
    }
  }
  const end = state.sliceDoc(paragraph.to - 1, paragraph.to);
  return { from: paragraph.to, insert: `${end === " " ? "" : " "}(see ${link()})` };
}

export interface RelatedState {
  /** End of the paragraph the items belong to (mapped through edits). */
  at: number;
  items: RelatedItem[];
}

export const setRelated = StateEffect.define<RelatedState | null>();
export const removeRelatedItem = StateEffect.define<string>();

export const relatedField = StateField.define<RelatedState | null>({
  create: () => null,
  update(value, transaction) {
    let next = value && transaction.docChanged ? { ...value, at: transaction.changes.mapPos(value.at, 1) } : value;
    for (const effect of transaction.effects) {
      if (effect.is(setRelated)) next = effect.value && effect.value.items.length ? effect.value : null;
      if (effect.is(removeRelatedItem) && next) {
        const items = next.items.filter((item) => item.target !== effect.value);
        next = items.length ? { ...next, items } : null;
      }
    }
    return next;
  },
  provide: (field) =>
    EditorView.decorations.compute([field], (state): DecorationSet => {
      const value = state.field(field);
      if (!value || value.at > state.doc.length) return Decoration.none;
      return Decoration.set([Decoration.widget({ widget: new RelatedWidget(value.items), side: 1 }).range(value.at)]);
    }),
});

/** Click handlers, set by the editor (it owns the host channel). */
export interface RelatedActions {
  accept(item: RelatedItem): void;
  dismiss(item: RelatedItem): void;
}

export const relatedActions = { current: null as RelatedActions | null };

class RelatedWidget extends WidgetType {
  constructor(readonly items: RelatedItem[]) {
    super();
  }

  override eq(other: RelatedWidget): boolean {
    return JSON.stringify(other.items) === JSON.stringify(this.items);
  }

  toDOM(): HTMLElement {
    const wrap = document.createElement("span");
    wrap.className = "cm-related";
    wrap.setAttribute("aria-label", "Related notes");
    for (const item of this.items) {
      const chip = document.createElement("span");
      chip.className = "cm-related-item";
      const link = document.createElement("button");
      link.className = "cm-related-link";
      link.textContent = `↗ ${item.title}`;
      link.title = item.detail ?? (item.mention ? `Link “${item.mention}”` : "Add a link to this paragraph");
      link.onmousedown = (event) => {
        event.preventDefault();
        relatedActions.current?.accept(item);
      };
      const close = document.createElement("button");
      close.className = "cm-related-dismiss";
      close.textContent = "×";
      close.title = "Not related";
      close.onmousedown = (event) => {
        event.preventDefault();
        relatedActions.current?.dismiss(item);
      };
      chip.append(link, close);
      wrap.append(chip);
    }
    return wrap;
  }

  override ignoreEvent(): boolean {
    return true;
  }
}
