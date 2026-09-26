// npm runs `prepare` on `npm install` from git, including a release
// tag. Release tags already carry the compiled CLI and the built
// viewer, so only build when they are missing (a branch checkout).
import fs from "node:fs";
import { execSync } from "node:child_process";

const built = ["src/cli/Cli.res.mjs", "dist/viewer/index.html"].every(file =>
  fs.existsSync(new URL(`../${file}`, import.meta.url)),
);

if (!built) {
  execSync("npm run build", { stdio: "inherit" });
}
