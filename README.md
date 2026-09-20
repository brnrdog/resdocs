# resdocs

An API documentation repository for ReScript packages. A CLI turns
the output of `rescript-tools doc` into one JSON bundle, a static
single page app renders it, and a GitHub Action publishes it to
Pages. One site documents one package; a second command writes an
index over many of them, so a single deployment can host the docs of
a whole ecosystem.

The viewer is written in ReScript with
[xote](https://github.com/brnrdog/xote) and rescript-signals: every
piece of UI state is a signal, and search and navigation update
synchronously per keystroke.

Live examples, generated from this repository's own workflow:

- https://brnrdog.github.io/resdocs/xote/
- https://brnrdog.github.io/resdocs/rescript-signals/

## Quick start for library authors

Document your package into `docs-site/` with one command:

    npx github:brnrdog/resdocs build --project . --out docs-site

Then publish it with the Action. Add `.github/workflows/docs.yml`:

    name: Docs
    on:
      push:
        branches: [main]
    permissions:
      contents: read
      pages: write
      id-token: write
    jobs:
      docs:
        runs-on: ubuntu-latest
        environment:
          name: github-pages
        steps:
          - uses: actions/checkout@v7
          - uses: brnrdog/resdocs@main

Enable GitHub Pages with "GitHub Actions" as the source, and the site
appears at `https://<user>.github.io/<repo>/`. Source links point at
the commit being built.

### Hosting several packages

`resdocs hub` writes an index page over a directory that already
holds one built package per subdirectory. Build each package with
`--hub` so its header links back:

    resdocs build --project deps/xote --out site/xote \
      --base /docs/xote/ --hub /docs/
    resdocs build --project deps/rescript-signals --out site/signals \
      --base /docs/signals/ --hub /docs/
    resdocs hub --out site --base /docs/ --title "ReScript API docs"

The index is plain HTML with no JavaScript. It reads each package's
name, version, description and module count out of its bundle. The
Action does the same with `command: hub`, which is how this
repository publishes both packages under one site
(`.github/workflows/docs.yml`).

### Action inputs

| Input          | Default             | Meaning                       |
| -------------- | ------------------- | ----------------------------- |
| `project`      | `.`                 | dir with `rescript.json`      |
| `out`          | `docs-site`         | output directory              |
| `base`         | `/<repo name>/`     | URL path of the site          |
| `repo`         | this repository     | repository URL, source links  |
| `ref`          | the built commit    | git ref for source links      |
| `dir`          | from `package.json` | package directory, monorepos  |
| `title`        | package name        | site title                    |
| `exclude`      |                     | module patterns, `Runtime*`   |
| `deploy`       | `true`              | upload and deploy to Pages    |
| `node-version` | `22`                | Node.js version               |

With `deploy: "false"` the Action only writes the site, which is how
this repository publishes two packages under one Pages site
(`.github/workflows/docs.yml`).

### CLI

    resdocs build [--project <dir>] [--out <dir>] [--base <path>]
                  [--repo <url>] [--ref <ref>] [--dir <path>]
                  [--hub <url>] [--title <text>] [--exclude <globs>]
                  [--bundle-only]

    resdocs hub [--out <dir>] [--base <path>] [--title <text>]
                [--tagline <text>]

The same options can live in `resdocs.config.json` next to
`rescript.json`:

    {
      "title": "xote",
      "repo": "https://github.com/brnrdog/xote",
      "ref": "main",
      "exclude": ["Runtime*"]
    }

The CLI compiles the project if `lib/bs` is missing, documents every
`.res` file in the non-dev sources through the `rescript-tools`
binary that ships with the project's own `rescript` install, and
warns about public items without a docstring.

### Writing docstrings and examples

Only `/** */` comments are documentation; `/* */` comments are not.
A `/*** */` comment at the top of a file documents the module.
Docstrings are Markdown with GitHub tables, compiled as MDX at build
time. Fenced blocks tagged `rescript` are syntax highlighted, which
is how examples are written, following the stdlib convention:

    /** Runs `f` once per item and collects the results.

    ## Examples

    ```rescript
    let doubled = run([1, 2, 3], x => x * 2)
    ```
    */

Examples are rendered, not compiled, so nothing checks that they
still typecheck. Text that is not valid MDX (an unclosed `<tag>` for
instance) is shown verbatim.

## Requirements

- ReScript 12. The `@rescript/tools` package on npm targets ReScript
  11 and prints nothing for a 12 build; the binary inside
  `@rescript/<platform>` is used instead.
- Node.js 20.11 or newer.

## Architecture

    src/core      shared by CLI and viewer, no DOM, no Node
      Docgen      types for the rescript-tools JSON
      Bundle      the normalized bundle, the CLI to viewer contract
      Normalize   docgen document to bundle module
      SigTokens   signature tokenizer
      Refs        type reference resolution
      Search      index and ranking
    src/cli       Node only
      Hub         the package index page
    src/viewer    browser only, xote components
    tests         Zekr suites (run with `npm test`)
    bench         Playwright harness (`npm run bench`)

The bundle is one JSON file. Ids are display paths computed from
nesting (`Xote.View.For.make`), each item carries its verbatim
signature plus the resolved references found in it, and docstrings
are stored both raw and as precompiled MDX. `docs/design.md` has the
full data model and `docs/api-survey.md` the survey of the tool
output it was derived from.

### How signals drive the UI

Every source of change is a signal and everything derived from it is
a `Computed`; components only read.

    bundle: Signal<option<bundle>>      set once after fetch
    location                            xote's router signal
    pathname   = Computed(location)     equality cutoff
    moduleId   = Computed(pathname)     equality cutoff
    module     = Computed(bundle, moduleId)
    query      = Signal<string>
    results    = Computed(index, query)
    selectedId = Computed(results, selected)
    theme      = Signal<theme>

Two cutoffs matter. `pathname` uses `~equals` so a hash-only change
(clicking an anchor) never touches the page. `selectedId` uses
`~equals` so moving the keyboard cursor re-runs exactly two
`aria-selected` attributes, not the results list.

Lists are `View.For` keyed by id: typing reorders existing result
rows instead of rebuilding them. Components are `@xote.component`,
so inline signal reads become fine-grained leaves. The only effects
touch what the DOM owns: the theme attribute, the document title,
the global `/` shortcut, and scrolling the selection or a deep link
target into view.

Rendered docstrings are xote nodes, not injected HTML: the CLI
compiles Markdown to an MDX function body, and the viewer runs it
against xote's JSX runtime through `Xote.Mdx`.

## Performance

Measured by `npm run bench` on the xote bundle (15 file modules, 30
modules in total, 188 items) in headless Chromium on a container
CPU. The harness types four queries character by character and
navigates between the largest module pages through the sidebar.
"Update" is the synchronous work inside the input event (search,
signals, DOM reconciliation) and "Render" the synchronous work
inside the link click; "Painted" waits two animation frames, so it
is bounded below by the display refresh interval.

Search (58 keystrokes, up to 50 results)

| Measure      | Median | p95   |
|--------------|--------|-------|
| Update (ms)  | 1.00   | 4.70  |
| Painted (ms) | 30.40  | 31.40 |

Module page render (median of 5)

| Module        | Items | Render (ms) | Painted (ms) |
|---------------|-------|-------------|--------------|
| Xote.View     | 53    | 6.70        | 32.90        |
| Xote.XoteJSX  | 29    | 13.00       | 39.70        |
| Xote.Router   | 16    | 4.50        | 23.00        |
| Xote.SSRState | 18    | 3.70        | 30.80        |

## Development

    npm install
    npm run build       compile ReScript and build the viewer
    npm test            Zekr suites
    npm run dev:bundle  document xote into public/ for the dev server
    npm run dev         Vite dev server
    npm run bench       benchmark on the xote bundle
    npm run docs:xote   full site for xote into docs-site/xote

## Design

The palette is ReScript's, used sparingly. The brand red,
`rgb(230, 72, 79)`, is a signal rather than a surface: it marks the
logo, the current module and the selected search result, and nothing
else. Links use a desaturated form of it at 6.2:1 on white. The
navy, `rgb(20, 22, 44)`, is the dark theme's paper rather than a
band across the top of the light one, and the light surface tone,
`oklch(0.928 0.006 264.531)`, is the border.

Long reading drove the rest. Body text is deliberately not black:
`#333846` reads at 11.7:1, clear of AA without the glare of a
near-black on white. Text runs to a 46rem measure at 16px and a
1.65 line height. Syntax highlighting is four hues, each at or above
5:1 on the code surface, with comments recessive through italics
rather than through low contrast. Item kinds are words in the muted
tone, not filled chips, and the per-item kind is dropped where the
section heading above already says it.

Corners are square, including the logo tile and what were pill
badges.

The logo is the ReScript tile with an open book where the letter
sits, in the same red, so the two read as a family without copying
the letterform. The mark lives in two places that must stay in sync,
`src/viewer/components/Logo.res` for the app and `Hub.logoFile` for
the favicon and the index page.

Item pages read in the order a reader needs: signature, then any
deprecation notice, then the prose, then the structural tables. A
variant's constructors are only expanded when one of them carries
its own documentation or an inline record, since the signature above
already lists them.

## Limitations

- xote and rescript-signals currently use `/* */` comments, so their
  generated sites show signatures, types and source links but no
  prose until those become `/** */`.
- `Stdlib` and `Dom` types are not linked.
- Search covers one package at a time. The index page links packages
  but does not search across them.
- No versioned docs and no server rendering.
