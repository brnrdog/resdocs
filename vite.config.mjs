import { defineConfig } from "vite";

// The base is a placeholder that the CLI replaces when it copies the
// built viewer next to a bundle, so one build serves any site path.
export default defineConfig(({ command }) => ({
  base: command === "build" ? "/__RESDOCS_BASE__/" : "/",
  build: {
    outDir: "dist/viewer",
    emptyOutDir: true,
    target: "es2022",
  },
}));
