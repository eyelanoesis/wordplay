import { defineConfig } from "vite";
import { viteSingleFile } from "vite-plugin-singlefile";

// Two builds share this config:
//   vite build                → dist/         (hosted app: separate assets, data fetched)
//   vite build --mode single  → dist-single/  (one offline HTML file, everything inlined)
// Modules check import.meta.env.MODE === "single" to switch data loading.
export default defineConfig(({ mode }) => ({
  plugins: mode === "single" ? [viteSingleFile()] : [],
  build: mode === "single" ? { outDir: "dist-single" } : { outDir: "dist" },
}));
