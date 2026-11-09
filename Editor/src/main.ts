import { GraniteEditor } from "./editor";

// Bundle entry: one editor per page, exposed to the Swift host as `window.granite`.
declare global {
  interface Window {
    granite: GraniteEditor;
  }
}

const parent = document.getElementById("editor") ?? document.body;
window.granite = new GraniteEditor({
  parent,
  fallback: (message) => console.debug("[granite → host]", message),
});
