import { type EditorState, type Range, StateField } from "@codemirror/state";
import { Decoration, type DecorationSet, EditorView, WidgetType } from "@codemirror/view";

/** The YAML block at the top of the document: `---` … `---` (or `...`). */
export function frontmatterRange(state: EditorState): { from: number; to: number; body: string } | null {
  const doc = state.doc;
  if (doc.lines < 2 || doc.line(1).text.trimEnd() !== "---") return null;
  for (let number = 2; number <= doc.lines; number++) {
    const text = doc.line(number).text.trimEnd();
    if (text === "---" || text === "...") {
      const end = doc.line(number);
      const body = number > 2 ? state.sliceDoc(doc.line(2).from, doc.line(number - 1).to) : "";
      return { from: 0, to: end.to, body };
    }
  }
  return null;
}

/** "type: claim · status: held · 5 properties": a one-line summary of the YAML. */
export function summarize(body: string): string {
  const keys: string[] = [];
  const shown: string[] = [];
  for (const line of body.split("\n")) {
    const match = /^([A-Za-z_][\w-]*):\s*(.*)$/.exec(line);
    if (!match) continue;
    const key = match[1]!;
    keys.push(key);
    const value = match[2]!.trim();
    if (["type", "status", "kind"].includes(key) && value) shown.push(`${key}: ${value}`);
  }
  const count = keys.length === 1 ? "1 property" : `${keys.length} properties`;
  return [...shown, count].join(" · ");
}

class PropertiesWidget extends WidgetType {
  constructor(readonly summary: string) {
    super();
  }
  override eq(other: PropertiesWidget) {
    return other.summary === this.summary;
  }
  toDOM(view: EditorView) {
    const element = document.createElement("div");
    element.className = "cm-properties";
    element.textContent = this.summary;
    element.title = "Click to edit properties";
    element.addEventListener("mousedown", (event) => {
      event.preventDefault();
      // Move into the YAML: the block unfolds because the selection is now inside it.
      view.dispatch({ selection: { anchor: view.state.doc.line(Math.min(2, view.state.doc.lines)).from } });
      view.focus();
    });
    return element;
  }
  override ignoreEvent() {
    return false;
  }
}

function decorations(state: EditorState): DecorationSet {
  const range = frontmatterRange(state);
  if (!range) return Decoration.none;
  const selection = state.selection.main;
  if (selection.from <= range.to && selection.to >= range.from) return Decoration.none;
  const decoration: Range<Decoration> = Decoration.replace({ widget: new PropertiesWidget(summarize(range.body)), block: true })
    .range(range.from, range.to);
  return Decoration.set([decoration]);
}

/** Folds the frontmatter into a properties summary until the cursor moves into it. */
export const frontmatterFold = StateField.define<DecorationSet>({
  create: decorations,
  update(value, transaction) {
    return transaction.docChanged || transaction.selection ? decorations(transaction.state) : value;
  },
  provide: (field) => EditorView.decorations.from(field),
});
