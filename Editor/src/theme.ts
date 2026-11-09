import { EditorView } from "@codemirror/view";

// Native-feeling theme: system font, system colors, light and dark via CSS variables in index.html.
export const theme = EditorView.theme({
  "&": {
    height: "100%",
    fontSize: "15px",
    color: "var(--text)",
    backgroundColor: "var(--background)",
  },
  "&.cm-focused": { outline: "none" },
  ".cm-scroller": {
    fontFamily: "-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif",
    lineHeight: "1.6",
  },
  ".cm-content": { maxWidth: "46em", margin: "0 auto", padding: "24px 28px 40vh", caretColor: "var(--accent)" },
  ".cm-activeLine": { backgroundColor: "transparent" },
  ".cm-cursor": { borderLeftColor: "var(--accent)", borderLeftWidth: "2px" },
  "&.cm-focused .cm-selectionBackground, .cm-selectionBackground, ::selection": {
    backgroundColor: "var(--selection) !important",
  },
  ".cm-heading": { fontWeight: "650", lineHeight: "1.3" },
  ".cm-h1": { fontSize: "1.75em", paddingTop: "0.6em" },
  ".cm-h2": { fontSize: "1.4em", paddingTop: "0.5em" },
  ".cm-h3": { fontSize: "1.2em", paddingTop: "0.4em" },
  ".cm-h4, .cm-h5, .cm-h6": { fontSize: "1.05em" },
  ".cm-em": { fontStyle: "italic" },
  ".cm-strong": { fontWeight: "650" },
  ".cm-strike": { textDecoration: "line-through", color: "var(--muted)" },
  ".cm-inline-code": {
    fontFamily: "ui-monospace, 'SF Mono', Menlo, monospace",
    fontSize: "0.9em",
    backgroundColor: "var(--code)",
    borderRadius: "3px",
    padding: "0 2px",
  },
  ".cm-code-block": {
    fontFamily: "ui-monospace, 'SF Mono', Menlo, monospace",
    fontSize: "0.9em",
    backgroundColor: "var(--code)",
  },
  ".cm-wikilink, .cm-embed": { color: "var(--accent)", cursor: "pointer" },
  ".cm-wikilink.cm-unresolved, .cm-embed.cm-unresolved": { color: "var(--muted)", textDecoration: "underline dotted" },
  ".cm-embed": { fontStyle: "italic" },
  ".cm-tag": { color: "var(--accent)", backgroundColor: "var(--tag)", borderRadius: "8px", padding: "0 4px" },
  ".cm-block-id": { color: "var(--muted)", fontSize: "0.8em" },
  ".cm-callout": { backgroundColor: "var(--callout)", borderLeft: "3px solid var(--accent)", paddingLeft: "10px" },
  ".cm-callout-title": { fontWeight: "600" },
  ".cm-url": { color: "var(--muted)" },
});
