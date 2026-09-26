# Contributing

## Setup

Node.js 20.11 or newer, then:

    npm install
    npm test            compile ReScript and run the Zekr suites
    npm run build       compile ReScript and build the viewer
    npm run bench       Playwright smoke and benchmark on xote

`README.md` explains the architecture and `docs/design.md` the data
model; read the relevant section before changing the bundle format.

## Changes

- Keep a pull request to one change, with tests for new behaviour.
  Core logic is tested in `tests/`; the CLI and the Action are tested
  end to end in CI on `fixtures/probe`.
- Add a line under `## Unreleased` in `CHANGELOG.md` for anything a
  user of the CLI, the Action or a generated site would notice.
- Changing the bundle shape means bumping `Bundle.version`; the
  viewer refuses bundles of any other version.
- Match the surrounding style: ReScript for logic, small `.mjs`
  helpers only where bindings would be heavier.

Releases are cut by a maintainer; see "Releasing" in `README.md`.

Security problems go through `SECURITY.md`, not public issues.
