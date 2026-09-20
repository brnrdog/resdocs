// Tiny static server with SPA fallback, used by the bench and the
// smoke test. Serves `dir` under `base` (for example "/xote/").
import fs from "node:fs";
import http from "node:http";
import path from "node:path";

const types = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
};

export function serve(dir, base = "/") {
  const server = http.createServer((req, res) => {
    const url = new URL(req.url, "http://localhost");
    let rel = url.pathname.startsWith(base) ? url.pathname.slice(base.length) : null;
    let file = rel === null ? null : path.join(dir, rel);
    if (file === null || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      // GitHub Pages behaviour: unknown paths get 404.html.
      file = path.join(dir, "404.html");
      res.statusCode = rel === null || rel === "" ? 200 : 404;
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
