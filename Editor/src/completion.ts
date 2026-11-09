import { autocompletion, type Completion, type CompletionContext, type CompletionResult } from "@codemirror/autocomplete";
import type { EditorView } from "@codemirror/view";
import type { CompletionItem } from "./bridge";

export type CompletionProvider = (kind: "link" | "tag", query: string) => Promise<CompletionItem[]>;

/** `[[query` before the cursor, outside an alias or anchor. */
export const linkTrigger = /\[\[([^[\]|#\n]*)$/;
/** `#query` at the start of a line or after whitespace (not a heading: headings need a space). */
export const tagTrigger = /(?:^|[\s(])#([\p{L}\p{N}_/-]*)$/u;

/** Inserts the title; if the auto-closed `]]` follows, the cursor jumps past it. */
function applyLink(title: string) {
  return (view: EditorView, _completion: Completion, from: number, to: number) => {
    const after = view.state.sliceDoc(to, to + 2);
    const insert = after === "]]" ? title : title + "]]";
    const end = from + insert.length + (after === "]]" ? 2 : 0);
    view.dispatch({ changes: { from, to, insert }, selection: { anchor: end }, userEvent: "input.complete" });
  };
}

export function linkCompletions(provider: CompletionProvider) {
  return async (context: CompletionContext): Promise<CompletionResult | null> => {
    const match = context.matchBefore(linkTrigger);
    if (!match) return null;
    const query = match.text.slice(2);
    const items = await provider("link", query);
    if (context.aborted) return null;
    return {
      from: match.from + 2,
      options: items.map((item) => ({
        label: item.label,
        detail: item.detail,
        apply: applyLink(item.apply ?? item.label),
        type: "text",
      })),
      // The host already filtered and ranked; don't let CodeMirror re-filter aliases away.
      filter: false,
    };
  };
}

export function tagCompletions(provider: CompletionProvider) {
  return async (context: CompletionContext): Promise<CompletionResult | null> => {
    const match = context.matchBefore(tagTrigger);
    if (!match) return null;
    const hash = match.text.lastIndexOf("#");
    const query = match.text.slice(hash + 1);
    if (query.length === 0 && !context.explicit) return null;
    const items = await provider("tag", query);
    if (context.aborted) return null;
    return {
      from: match.from + hash + 1,
      options: items.map((item) => ({ label: item.label, detail: item.detail, apply: item.apply ?? item.label, type: "keyword" })),
      filter: false,
    };
  };
}

export function graniteCompletion(provider: CompletionProvider) {
  return autocompletion({
    override: [linkCompletions(provider), tagCompletions(provider)],
    activateOnTyping: true,
    icons: false,
  });
}
