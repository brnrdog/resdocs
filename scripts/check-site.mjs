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
  if (title !== undefined) {
    check(html.includes(`<title>${title}</title>`), `index.html title is not ${title}`);
  }

  // Pre-rendered pages: markup inside #app, one page per top module.
  const rendered = (file, text) => {
    const page = fs.existsSync(path.join(dir, file)) ? read(file) : null;
    check(page !== null, `${file} is missing`);
    if (page !== null) {
      check(!page.includes('<div id="app"></div>'), `${file} is not pre-rendered`);
      check(page.includes(text), `${file} does not contain ${text}`);
    }
  };
  rendered("index.html", 'class="package-hero"');
  for (const m of bundle.modules) {
    rendered(`module/${m.id}/index.html`, `<title>${m.id} - `);
  }
  rendered(`module/${moduleId}/index.html`, 'class="item"');
  rendered("404.html", "<title>Page not found - ");
}

if (failures.length > 0) {
  for (const f of failures) console.error(`check-site: ${dir}: ${f}`);
  process.exit(1);
}
console.log(`check-site: ${dir} ok`);
