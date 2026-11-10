import { defineConfig } from "vite";

// The web clipper bundle: Defuddle plus sanitizing, as one classic script the app injects into
// clipped pages (in an isolated content world). Built next to the editor bundle.
export default defineConfig({
  build: {
    outDir: "../App/Resources/editor",
    emptyOutDir: false,
    license: { fileName: "clipper-third-party.md" },
    target: "safari18",
    sourcemap: false,
    minify: true,
    lib: {
      entry: "src/clipper.ts",
      formats: ["iife"],
      name: "GraniteClipperBundle",
      fileName: () => "clipper.js",
    },
  },
});
