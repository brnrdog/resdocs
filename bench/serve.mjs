// Static server with GitHub Pages semantics, used by the bench and
// the smoke tests: a directory serves its index.html, and an unknown
// path serves the nearest 404.html above it.
import fs from "node:fs";
import http from "node:http";
import path from "node:path";

const types = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
};

const isFile = p => fs.existsSync(p) && fs.statSync(p).isFile();

// Nearest 404.html at or above `rel`, the way Pages resolves one.
function notFoundPage(dir, rel) {
  let current = path.join(dir, rel);
  for (;;) {
    const candidate = path.join(current, "404.html");
    if (isFile(candidate)) return candidate;
    if (path.resolve(current) === path.resolve(dir)) return null;
    current = path.dirname(current);
  }
}

export function serve(dir, base = "/") {
  const server = http.createServer((req, res) => {
    const url = new URL(req.url, "http://localhost");
    const rel = url.pathname.startsWith(base) ? decodeURIComponent(url.pathname.slice(base.length)) : null;
    let file = null;
    if (rel !== null) {
      const target = path.join(dir, rel);
      if (isFile(target)) file = target;
      else if (isFile(path.join(target, "index.html"))) file = path.join(target, "index.html");
    }
    if (!file) {
      file = rel === null ? null : notFoundPage(dir, path.dirname(rel));
      res.statusCode = 404;
    }
    if (!file) {
      res.statusCode = 404;
      res.setHeader("content-type", "text/plain");
      res.end("not found");
      return;
    }
    res.setHeader("content-type", types[path.extname(file)] ?? "application/octet-stream");
    fs.createReadStream(file).pipe(res);
  });
  return new Promise(resolve =>
    server.listen(0, "127.0.0.1", () => {
      const { port } = server.address();
      resolve({ url: `http://127.0.0.1:${port}${base}`, close: () => server.close() });
    }),
  );
}
