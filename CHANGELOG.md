# Changelog

Each release has a `## <version>` section; the release workflow
publishes that section as the GitHub release notes and refuses to
run without it. Unreleased changes go under `## Unreleased` until a
version is picked.

## Unreleased

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
