// Node-only glue for the CLI: things that are simpler in JavaScript
// than through bindings. Everything else lives in the .res files.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { compile, runSync } from "@mdx-js/mdx";
import remarkGfm from "remark-gfm";
import * as runtime from "xote/jsx-runtime";

// Root of the resdocs package itself (this file is src/cli/helpers.mjs).
export const packageRoot = fileURLToPath(new URL("../../", import.meta.url));

// Walk up from `fromDir` to find node_modules/<name>. Returns the
// package directory or null.
export function findPackageDir(fromDir, name) {
  let dir = path.resolve(fromDir);
  for (;;) {
    const candidate = path.join(dir, "node_modules", name);
    if (fs.existsSync(path.join(candidate, "package.json"))) {
      return candidate;
    }
    const parent = path.dirname(dir);
    if (parent === dir) {
      return null;
    }
    dir = parent;
  }
}

// Paths of the compiler binaries, resolved the way rescript's own CLI
// does it (cli/common/bins.js picks the @rescript/<platform> package).
export async function rescriptBins(rescriptDir) {
  const mod = await import(path.join(rescriptDir, "cli", "common", "bins.js"));
  return { tools: mod.rescript_tools_exe, rescript: mod.rescript_exe };
}

// Compile one docstring to an MDX function body and prove that it
// runs against xote's JSX runtime. Returns null when the text is not
// valid MDX, so the viewer falls back to plain text.
export async function compileDoc(markdown) {
  try {
    const code = String(
      await compile(markdown, {
        outputFormat: "function-body",
        remarkPlugins: [remarkGfm],
        development: false,
      }),
    );
    const mod = runSync(code, { ...runtime, baseUrl: "file:///" });
    mod.default({});
    return code;
  } catch {
    return null;
  }
}

export function copyDir(src, dst) {
  fs.cpSync(src, dst, { recursive: true });
}

export function nowIso() {
  return new Date().toISOString();
}
