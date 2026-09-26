// Checks a site written by `resdocs build`, for CI:
//   node scripts/check-site.mjs <dir> <base> <module> [title]
// Exits non-zero with a message on the first thing that is wrong.
import fs from "node:fs";
import path from "node:path";

const [dir, base, moduleId, title] = process.argv.slice(2);
if (!dir || !base || !moduleId) {
  console.error("usage: check-site.mjs <dir> <base> <module> [title]");
  process.exit(2);
}

const failures = [];
const check = (ok, message) => ok || failures.push(message);
const read = file => fs.readFileSync(path.join(dir, file), "utf8");

for (const file of ["index.html", "404.html", "resdocs.json", "logo.svg"]) {
  check(fs.existsSync(path.join(dir, file)), `${file} is missing`);
}

if (failures.length === 0) {
  const bundle = JSON.parse(read("resdocs.json"));
  const html = read("index.html");
  const walk = m => [m, ...m.modules.flatMap(walk)];
  const modules = bundle.modules.flatMap(walk);
  const items = modules.flatMap(m => [...m.types, ...m.values]);

  check(bundle.version === 2, `bundle version is ${bundle.version}, expected 2`);
  check(modules.some(m => m.id === moduleId), `no module ${moduleId}`);
  check(items.length > 0, "no items");
  check(
    items.some(i => Array.isArray(i.docTree) && i.docTree.length > 0),
    "no item has a parsed docstring",
  );
  for (const placeholder of ["/__RESDOCS_BASE__/", "__RESDOCS_TITLE__"]) {
    check(!html.includes(placeholder), `index.html still has ${placeholder}`);
  }
  check(html.includes(`window.__RESDOCS_BASE__ = "${base}"`), `index.html base is not ${base}`);
  check(read("404.html") === html, "404.html differs from index.html");
  if (title !== undefined) {
    check(html.includes(`<title>${title}</title>`), `index.html title is not ${title}`);
  }
}

if (failures.length > 0) {
  for (const f of failures) console.error(`check-site: ${dir}: ${f}`);
  process.exit(1);
}
console.log(`check-site: ${dir} ok`);
