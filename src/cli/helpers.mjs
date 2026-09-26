// Node-only glue for the CLI: things that are simpler in JavaScript
// than through bindings. Everything else lives in the .res files.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { unified } from "unified";
import remarkParse from "remark-parse";
import remarkGfm from "remark-gfm";
import remarkRehype from "remark-rehype";

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

// Parse one docstring as Markdown with GitHub extensions into the
// tree Doc.res describes. Raw HTML is kept as literal text, never as
// markup, and nothing in the docstring is evaluated: MDX expressions
// such as `{...}` are just braces. Doc.sanitize runs on the result.
function htmlAsText() {
  const blocks = new Set(["root", "blockquote", "listItem", "footnoteDefinition"]);
  return tree => {
    const walk = node => {
      node.children?.forEach((child, i) => {
        if (child.type !== "html") {
          walk(child);
        } else if (blocks.has(node.type)) {
          node.children[i] = { type: "paragraph", children: [{ type: "text", value: child.value }] };
        } else {
          child.type = "text";
        }
      });
    };
    walk(tree);
  };
}

const withHtmlAsText = unified()
  .use(remarkParse)
  .use(remarkGfm)
  .use(htmlAsText)
  .use(remarkRehype);

function attrValue(value) {
  if (Array.isArray(value)) return value.join(" ");
  if (value === true) return "";
  return String(value);
}

function attrName(name) {
  if (name === "className") return "class";
  if (name.startsWith("data")) return null;
  if (name.startsWith("aria")) return "aria-" + name.slice(4).toLowerCase();
  return name.toLowerCase();
}

function toDoc(node) {
  if (node.type === "text") {
    return [{ t: "x", value: node.value }];
  }
  if (node.type === "element") {
    const attrs = [];
    for (const [key, value] of Object.entries(node.properties ?? {})) {
      const name = attrName(key);
      if (name !== null && value !== false && value != null) {
        attrs.push([name, attrValue(value)]);
      }
    }
    return [{ t: "e", tag: node.tagName, attrs, children: node.children.flatMap(toDoc) }];
  }
  if (node.type === "root") {
    return node.children.flatMap(toDoc);
  }
  return [];
}

export function parseDoc(text) {
  const tree = withHtmlAsText.runSync(withHtmlAsText.parse(text));
  return toDoc(tree);
}

export function copyDir(src, dst) {
  fs.cpSync(src, dst, { recursive: true });
}

export function nowIso() {
  return new Date().toISOString();
}
