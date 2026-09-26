# Changelog

Each release has a `## <version>` section; the release workflow
publishes that section as the GitHub release notes and refuses to
run without it. Unreleased changes go under `## Unreleased` until a
version is picked.

## Unreleased

- Every page is pre-rendered at build time: the home page, one page
  per top level module (`module/<id>/index.html`) and `404.html`,
  each with its own title and meta description. Pages read without
  JavaScript and are indexable, module URLs return 200 instead of
  going through `404.html`, and unknown paths return a real 404. The
  live app takes over once the bundle has loaded.

- A build now fails, and writes nothing, when any source file cannot
  be documented or when no source files are left after `--exclude`.
  Before, such files were skipped with a warning and an empty or
  partial site could be deployed.
- The CLI always compiles the project first (incrementally), so it
  never documents a stale build.
- `--strict`, `"strict": true` in `resdocs.config.json` and the
  Action's `strict` input fail the build on public items without a
  docstring.
- The viewer shows why the docs could not load (network or HTTP
  error, invalid JSON, a bundle from another resdocs version) instead
  of staying on "Loading documentation...".
- Depends on the stable xote 7.1.0 instead of a 7.2 beta.

## 0.1.0

First release.

- `resdocs build` documents a ReScript 12 package into one JSON
  bundle and a static single page viewer: sidebar, per-module pages,
  linked type signatures, source links and keyboard search.
- `resdocs hub` writes a plain HTML index over several built
  packages, so one site can host a whole ecosystem.
- A GitHub Action builds and deploys the site to Pages, with
  `command: hub` for multi-package sites.
- Docstrings are Markdown with GitHub extensions, parsed into a
  sanitized tree. Nothing in a docstring is evaluated, raw HTML is
  shown as text, and links are kept only for http, https, mailto and
  relative URLs.
- Release tags carry the compiled CLI and the built viewer, so the
  Action and `npx github:brnrdog/resdocs#v0.1.0` install without a
  build.
