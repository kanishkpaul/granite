import { markdown, markdownLanguage } from "@codemirror/lang-markdown";
import { ensureSyntaxTree } from "@codemirror/language";
import { EditorSelection, EditorState } from "@codemirror/state";
import { describe, expect, it, vi } from "vitest";
import type { EditorMessage, RelatedItem } from "../src/bridge";
import { GraniteEditor } from "../src/editor";
import { acceptChange, paragraphAt, relatedField, removeRelatedItem, setRelated, wordCount } from "../src/related";

function state(doc: string, cursor = doc.length) {
  const s = EditorState.create({
    doc, selection: EditorSelection.cursor(cursor), extensions: [markdown({ base: markdownLanguage }), relatedField],
  });
  ensureSyntaxTree(s, s.doc.length, 5000);
  return s;
}

const mention: RelatedItem = { target: "Reciprocal rank fusion", title: "Reciprocal rank fusion", reason: "mention", mention: "RRF" };
const similar: RelatedItem = { target: "Garage", title: "Garage", reason: "similar" };

describe("paragraphAt", () => {
  const doc = "---\ntitle: x\n---\n# Heading\nFirst line of a paragraph\nsecond line.\n\nAnother one.\n```\ncode here\n```\n";

  it("spans neighbouring lines and stops at blanks and headings", () => {
    const s = state(doc);
    const p = paragraphAt(s, doc.indexOf("second"));
    expect(p?.text).toBe("First line of a paragraph\nsecond line.");
    expect(paragraphAt(s, doc.indexOf("Another"))?.text).toBe("Another one.");
  });

  it("is null in frontmatter, headings and code", () => {
    const s = state(doc);
    expect(paragraphAt(s, doc.indexOf("title"))).toBeNull();
    expect(paragraphAt(s, doc.indexOf("Heading") + 2)).toBeNull();
    expect(paragraphAt(s, doc.indexOf("code here") + 2)).toBeNull();
  });

  it("counts words", () => {
    expect(wordCount("one two — three [[x]] 4")).toBe(5);
  });
});

describe("accepting a related note", () => {
  it("links a mention in place, keeping the written words as the alias", () => {
    const doc = "We fuse lists with rrf here.";
    const s = state(doc);
    const change = acceptChange(s, { from: 0, to: doc.length }, mention);
    expect(s.update({ changes: change ?? [] }).state.doc.toString()).toBe("We fuse lists with [[Reciprocal rank fusion|rrf]] here.");
    const exact = acceptChange(state("about reciprocal rank fusion"), { from: 0, to: 28 }, { ...mention, mention: "reciprocal rank fusion" });
    expect(state("about reciprocal rank fusion").update({ changes: exact ?? [] }).state.doc.toString())
      .toBe("about [[Reciprocal rank fusion]]");
  });

  it("appends a see-link for similar notes", () => {
    const doc = "My car needs brakes.";
    const s = state(doc);
    const change = acceptChange(s, { from: 0, to: doc.length }, similar);
    expect(s.update({ changes: change ?? [] }).state.doc.toString()).toBe("My car needs brakes. (see [[Garage]])");
  });

  it("keeps ghost links anchored through edits and drops removed ones", () => {
    let s = state("Paragraph text.");
    s = s.update({ effects: setRelated.of({ at: 15, items: [mention, similar] }) }).state;
    s = s.update({ changes: { from: 0, insert: "New " } }).state;
    expect(s.field(relatedField)?.at).toBe(19);
    s = s.update({ effects: removeRelatedItem.of("Garage") }).state;
    expect(s.field(relatedField)?.items.map((i) => i.target)).toEqual(["Reciprocal rank fusion"]);
    s = s.update({ effects: removeRelatedItem.of("Reciprocal rank fusion") }).state;
    expect(s.field(relatedField)).toBeNull();
  });
});

describe("editor round trip", () => {
  it("sends the paragraph after a pause, shows the answer, and reports decisions", () => {
    vi.useFakeTimers();
    const sent: EditorMessage[] = [];
    const editor = new GraniteEditor({ parent: document.createElement("div"), fallback: (m) => sent.push(m), contextDelay: 50 });
    const text = "# Notes\nWe fuse the ranked lists with RRF before the reranker sees them.\n";
    editor.receive({ type: "load", path: "Notes/a.md", text, version: 1, cursor: text.indexOf("RRF") });
    editor.view.dispatch({ selection: { anchor: text.indexOf("RRF") + 1 } });
    vi.advanceTimersByTime(60);
    const context = sent.find((m) => m.type === "context");
    expect(context).toMatchObject({ type: "context", text: "We fuse the ranked lists with RRF before the reranker sees them.", line: 2 });
    const id = (context as { id: number }).id;

    editor.receive({ type: "related", id: id + 99, items: [mention] });
    expect(editor.view.state.field(relatedField)).toBeNull();
    editor.receive({ type: "related", id, items: [mention, similar] });
    expect(editor.view.state.field(relatedField)?.items).toHaveLength(2);
    expect(editor.view.dom.querySelectorAll(".cm-related-item")).toHaveLength(2);

    // Clicking the first ghost link inserts the link and tells the host.
    const link = editor.view.dom.querySelector<HTMLElement>(".cm-related-link");
    link?.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    expect(editor.view.state.doc.toString()).toContain("with [[Reciprocal rank fusion|RRF]] before");
    expect(sent).toContainEqual({ type: "relatedDecision", target: "Reciprocal rank fusion", decision: "accepted" });
    editor.view.dom.querySelector<HTMLElement>(".cm-related-dismiss")?.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    expect(sent).toContainEqual({ type: "relatedDecision", target: "Garage", decision: "dismissed" });
    expect(editor.view.state.field(relatedField)).toBeNull();

    // A short paragraph sends nothing.
    const before = sent.filter((m) => m.type === "context").length;
    editor.receive({ type: "load", path: "Notes/b.md", text: "Too short.", version: 1, cursor: 3 });
    editor.view.dispatch({ selection: { anchor: 4 } });
    vi.advanceTimersByTime(60);
    expect(sent.filter((m) => m.type === "context").length).toBe(before);
    vi.useRealTimers();
  });
});
