import { defineConfig } from "vitest/config";

// Builds a classic-script bundle (IIFE) plus public/editor.html into the app's resources.
// Classic scripts load reliably from file:// in WKWebView; ES modules can be blocked there.
// `pnpm dev` serves index.html for working on the editor in a browser.
export default defineConfig({
  build: {
    outDir: "../App/Resources/editor",
    emptyOutDir: true,
    license: { fileName: "editor-third-party.md" },
    target: "safari18",
    sourcemap: false,
    minify: true,
    lib: {
      entry: "src/main.ts",
      formats: ["iife"],
      name: "GraniteEditorBundle",
      fileName: () => "editor.js",
    },
  },
  test: {
    environment: "jsdom",
    include: ["test/**/*.test.ts"],
    setupFiles: ["test/setup.ts"],
  },
});
