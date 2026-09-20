// Performance harness: builds the xote site, then measures search
// update latency and module page render time in headless Chromium.
// Usage: node bench/bench.mjs [--site <dir>] [--json]
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";
import { serve } from "./serve.mjs";

const root = fileURLToPath(new URL("..", import.meta.url));
const args = process.argv.slice(2);
const arg = name => (args.includes(name) ? args[args.indexOf(name) + 1] : undefined);
const json = args.includes("--json");

let site = arg("--site");
if (!site) {
  site = path.join(root, ".bench", "site");
  execFileSync(
    process.execPath,
    [path.join(root, "bin", "resdocs.mjs"), "build", "--project", path.join(root, "node_modules", "xote"),
      "--out", site, "--exclude", "Runtime*"],
    { stdio: "ignore" },
  );
}

const median = xs => { const s = [...xs].sort((a, b) => a - b); return s[Math.floor(s.length / 2)]; };
const p95 = xs => { const s = [...xs].sort((a, b) => a - b); return s[Math.min(s.length - 1, Math.floor(s.length * 0.95))]; };
const fmt = x => x.toFixed(2);

const { url, close } = await serve(site, "/");
const executablePath =
  process.env.RESDOCS_CHROMIUM ?? (fs.existsSync("/opt/pw-browsers/chromium") ? "/opt/pw-browsers/chromium" : undefined);
const browser = await chromium.launch({ executablePath });
const page = await browser.newPage();
await page.goto(url + "module/Xote.View");
await page.waitForSelector("#value-eachWithKey");

// One keystroke: set the value, dispatch `input`, and measure both the
// synchronous update (signals and DOM reconciliation run inside the
// event) and the time until the next frame has painted.
async function keystroke(value) {
  return page.evaluate(async value => {
    const input = document.getElementById("search-input");
    input.value = value;
    const t0 = performance.now();
    input.dispatchEvent(new Event("input", { bubbles: true }));
    const sync = performance.now() - t0;
    await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)));
    const paint = performance.now() - t0;
    return { sync, paint, results: document.querySelectorAll(".result").length };
  }, value);
}

async function typeSequence(text) {
  const samples = [];
  for (let i = 1; i <= text.length; i++) samples.push(await keystroke(text.slice(0, i)));
  for (let i = text.length - 1; i >= 1; i--) samples.push(await keystroke(text.slice(0, i)));
  await keystroke("");
  return samples;
}

await page.click("#search-input");
await typeSequence("eachWithKey"); // warm up
const searchSamples = [
  ...(await typeSequence("eachWithKey")),
  ...(await typeSequence("signal")),
  ...(await typeSequence("e")),
  ...(await typeSequence("MaybeSignal.t")),
];

// Module page render: navigating through a sidebar link. Router.push
// and the page rebuild are synchronous, so the click duration is the
// render time; paint adds the next frame.
async function renderModule(id) {
  return page.evaluate(async id => {
    const link = [...document.querySelectorAll(".nav-link")].find(a => a.textContent === id);
    const t0 = performance.now();
    link.click();
    const sync = performance.now() - t0;
    await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)));
    const paint = performance.now() - t0;
    return { sync, paint, items: document.querySelectorAll(".item").length };
  }, id);
}

const modules = ["Xote.View", "Xote.XoteJSX", "Xote.Router", "Xote.SSRState"];
const renders = {};
for (let round = 0; round < 6; round++) {
  for (const id of modules) {
    await renderModule(id === "Xote.View" ? "Xote.Signal" : "Xote.View"); // leave the page first
    const sample = await renderModule(id);
    if (round > 0) (renders[id] ??= []).push(sample);
  }
}

await browser.close();
close();

const report = {
  search: {
    keystrokes: searchSamples.length,
    maxResults: Math.max(...searchSamples.map(s => s.results)),
    syncMedianMs: median(searchSamples.map(s => s.sync)),
    syncP95Ms: p95(searchSamples.map(s => s.sync)),
    paintMedianMs: median(searchSamples.map(s => s.paint)),
    paintP95Ms: p95(searchSamples.map(s => s.paint)),
  },
  render: Object.fromEntries(
    modules.map(id => [id, {
      items: renders[id][0].items,
      syncMedianMs: median(renders[id].map(s => s.sync)),
      paintMedianMs: median(renders[id].map(s => s.paint)),
    }]),
  ),
};

if (json) {
  console.log(JSON.stringify(report, null, 2));
} else {
  console.log(`Search (${report.search.keystrokes} keystrokes, up to ${report.search.maxResults} results)`);
  console.log("");
  console.log("| Measure | Median | p95 |");
  console.log("|---|---|---|");
  console.log(`| Update (sync, ms) | ${fmt(report.search.syncMedianMs)} | ${fmt(report.search.syncP95Ms)} |`);
  console.log(`| Painted (ms) | ${fmt(report.search.paintMedianMs)} | ${fmt(report.search.paintP95Ms)} |`);
  console.log("");
  console.log("Module page render (median of 5)");
  console.log("");
  console.log("| Module | Items | Render (ms) | Painted (ms) |");
  console.log("|---|---|---|---|");
  for (const [id, r] of Object.entries(report.render)) {
    console.log(`| ${id} | ${r.items} | ${fmt(r.syncMedianMs)} | ${fmt(r.paintMedianMs)} |`);
  }
}
