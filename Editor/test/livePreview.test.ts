import { markdown, markdownLanguage } from "@codemirror/lang-markdown";
import { ensureSyntaxTree } from "@codemirror/language";
import { EditorSelection, EditorState } from "@codemirror/state";
import { describe, expect, it } from "vitest";
import { computeDecorations, type DecorationSpec, resolvedTargets, setResolvedEffect } from "../src/livePreview";
import { linkKey, obsidianSyntax, parseTarget } from "../src/wikilink";

function state(doc: string, cursor = doc.length, resolved?: string[]): EditorState {
  let s = EditorState.create({
    doc,
    selection: EditorSelection.cursor(cursor),
    extensions: [markdown({ base: markdownLanguage, extensions: [obsidianSyntax] }), resolvedTargets],
  });
  if (resolved) s = s.update({ effects: setResolvedEffect.of(new Set(resolved)) }).state;
  ensureSyntaxTree(s, s.doc.length, 5000);
  return s;
}

const text = (s: EditorState, spec: DecorationSpec) => ("to" in spec ? s.sliceDoc(spec.from, spec.to) : "");
const hidden = (s: EditorState, specs: DecorationSpec[]) => specs.filter((d) => d.kind === "hide").map((d) => text(s, d));
const marks = (s: EditorState, specs: DecorationSpec[], cls: string) =>
  specs.filter((d) => d.kind === "mark" && d.className.split(" ").includes(cls)).map((d) => text(s, d));

describe("live preview", () => {
  it("hides heading marks off the cursor line and shows them on it", () => {
    const doc = "# Title\n\nbody";
    const off = state(doc);
    expect(hidden(off, computeDecorations(off))).toContain("# ");
    const lines = computeDecorations(off).filter((d) => d.kind === "line");
    expect(lines).toEqual([{ kind: "line", from: 0, className: "cm-heading cm-h1" }]);
    const on = state(doc, 3);
    expect(hidden(on, computeDecorations(on))).not.toContain("# ");
  });

  it("renders wikilink aliases and keeps raw syntax on the active line", () => {
    const doc = "See [[Target note#Part|the alias]] here.\n\nnext";
    const off = state(doc);
    const specs = computeDecorations(off);
    expect(marks(off, specs, "cm-wikilink")).toEqual(["the alias"]);
    expect(hidden(off, specs)).toEqual(["[[Target note#Part|", "]]"]);
    const on = state(doc, 5);
    const active = computeDecorations(on);
    expect(hidden(on, active)).toEqual([]);
    expect(marks(on, active, "cm-wikilink")).toEqual(["Target note#Part"]);
  });

  it("marks unresolved links once the host sends resolved targets", () => {
    const doc = "[[Known]] and [[Missing]] and ![[Known.md]]\n\nx";
    const before = state(doc);
    expect(marks(before, computeDecorations(before), "cm-unresolved")).toEqual([]);
    const after = state(doc, doc.length, ["known"]);
    const specs = computeDecorations(after);
    expect(marks(after, specs, "cm-unresolved")).toEqual(["Missing"]);
    expect(marks(after, specs, "cm-embed")).toEqual(["Known.md"]);
  });

  it("styles tags, block ids, emphasis and callouts", () => {
    const doc = "Some *em* and **strong** #tag/sub not#tag 123 #2026 ^block-1\n\n> [!note] Title\n> body\n\nend";
    const s = state(doc);
    const specs = computeDecorations(s);
    expect(marks(s, specs, "cm-tag")).toEqual(["#tag/sub"]);
    expect(marks(s, specs, "cm-block-id")).toEqual(["^block-1"]);
    expect(marks(s, specs, "cm-em")).toEqual(["*em*"]);
    expect(marks(s, specs, "cm-strong")).toEqual(["**strong**"]);
    expect(hidden(s, specs)).toEqual(["*", "*", "**", "**"]);
    const callouts = specs.filter((d) => d.kind === "line" && d.className.includes("cm-callout"));
    expect(callouts.map((d) => (d.kind === "line" ? d.className : ""))).toEqual([
      "cm-callout cm-callout-title cm-callout-note",
      "cm-callout cm-callout-note",
    ]);
  });

  it("leaves code alone", () => {
    const doc = "```\n[[not a link]] #nottag\n```\n\n`[[inline]]`\n\nx";
    const s = state(doc);
    const specs = computeDecorations(s);
    expect(marks(s, specs, "cm-wikilink")).toEqual([]);
    expect(marks(s, specs, "cm-tag")).toEqual([]);
    expect(specs.filter((d) => d.kind === "line" && d.className === "cm-code-block")).toHaveLength(3);
  });

  it("only decorates the requested ranges", () => {
    const doc = Array.from({ length: 2000 }, (_, i) => `line ${i} [[Link ${i}]]`).join("\n");
    const s = state(doc, 0);
    const line = s.doc.line(1000);
    const specs = computeDecorations(s, [{ from: line.from, to: line.to }]);
    expect(marks(s, specs, "cm-wikilink")).toEqual(["Link 999"]);
  });
});

describe("link targets match KBCore", () => {
  it("normalizes keys", () => {
    expect(linkKey("Folder/Note.MD")).toBe("folder/note");
    expect(linkKey(" Note#Heading ")).toBe("note");
  });
  it("splits anchors", () => {
    expect(parseTarget("Note#^abc")).toEqual({ target: "Note", blockID: "abc" });
    expect(parseTarget("Note#A#B")).toEqual({ target: "Note", heading: "B" });
    expect(parseTarget("#Section")).toEqual({ target: "", heading: "Section" });
  });
});
