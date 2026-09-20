# Repo layout and data model

Step 2 of the process. Builds on `docs/api-survey.md`.

## 1. Repo layout

One npm package, one ReScript project, three source roots. The CLI
and the viewer share the bundle types so a change in the JSON shape
breaks both at compile time.

    resdocs/
      package.json           bin: resdocs, scripts: build, test, bench
      rescript.json          sources: src, tests; jsx XoteJSX; ppx
      vite.config.mjs        base placeholder, outDir dist/viewer
      index.html             Vite entry, mounts the SPA
      bin/resdocs.mjs        CLI entry
      action.yml             reusable GitHub Action (composite)
      README.md
      docs/
        api-survey.md        step 1
        design.md            this file
        survey/              raw rescript-tools output samples
      src/
        core/                shared by CLI and viewer, no DOM
          Docgen.res         types for rescript-tools JSON, decoder
          Bundle.res         normalized bundle types, JSON codec
          Normalize.res      docgen doc -> bundle module
          Path.res           module path helpers, id and anchor rules
          Refs.res           type reference resolution
          Search.res         index build, query, ranking
          SigTokens.res      signature tokenizer, shared with viewer
        cli/
          Cli.res            entry: parse args, run pipeline, write
          Hub.res            the package index page
          Project.res        read rescript.json, list source files
          Tools.res          locate and run rescript-tools
          Node.res           fs, path, child_process externals
          helpers.mjs        binary lookup, MDX compile, copy
        viewer/
          Main.res           Router.init, fetch, document effects
          Store.res          signals and computeds, see section 5
          Browser.res        DOM externals beyond xote
          Markdown.res       runs precompiled MDX through Xote.Mdx
          Signature.res      signature with type links
          Highlight.res      ReScript syntax highlighting
          components/
            App.res          layout shell, page switch
            Header.res       hub link, package identity, actions
            Logo.res         the book mark
            PackageHome.res  package landing page
            Sidebar.res      module tree, View.For over modules
            SidebarEntry.res one top level module and its subtree
            ModulePage.res   current module or not found
            ModuleView.res   types, values, submodules, item cards
            SearchBox.res    input, results, keyboard navigation
            ThemeToggle.res
          styles.css         ReScript palette, light and dark
          logo.svg           favicon
      tests/
        NormalizeTest.res    Zekr, fixture driven
        SearchTest.res       Zekr, ranking assertions
        RefsTest.res
        SigTokensTest.res
        HubTest.res          index page rendering
        ViewerTest.res       markdown, signature, highlight in jsdom
        fixtures/            rescript-tools output samples
      fixtures/probe/        the probe package the fixtures come from
      bench/
        bench.mjs            Playwright: search latency, page render
        serve.mjs            static server with Pages-style 404
      .github/workflows/
        ci.yml               build, test, bench on the xote bundle
        docs.yml             dogfood: build both sites, deploy Pages

Notes on the split:

- `src/core` compiles to ESM that runs in both Node and the browser.
  It must not reference `Dom` or `process`.
- `src/cli` is Node only. Its one use of xote is running each
  compiled docstring once, to reject MDX that would fail at render.
- `src/viewer` is browser only. It reads the bundle over `fetch`.
- Tests live in `tests/` with a `Test.res` suffix (`zekr.json` sets
  the pattern; a `.test.res` name would shadow the module under
  test). `rescript.json` marks `tests` as `type: dev`.

## 2. CLI behaviour

    resdocs build [--project <dir>] [--out <dir>] [--repo <url>]
                  [--ref <git ref>] [--base <url path>]

1. Read `<dir>/rescript.json`: `name`, `namespace` (`true`, a string
   or absent), `sources` (dev sources are skipped) and `suffix`.
2. Ensure the project is compiled. If `lib/bs` is missing, run
   `rescript build` in `<dir>` and fail loudly if that fails.
3. Locate `rescript-tools.exe` inside `@rescript/<platform>` resolved
   from the project's `rescript` install, falling back to ours.
4. For each `.res` file in the sources, run `rescript-tools doc`,
   decode, normalize (section 3). A file that has a `.resi` sibling
   is documented through the interface automatically.
5. Write `<out>/resdocs.json` (the bundle) and copy the built viewer
   next to it, plus `404.html`.

Config can also come from `resdocs.config.json` in the project root
so the Action needs no arguments:

    {"repo": "https://github.com/brnrdog/xote", "ref": "main",
     "dir": "", "exclude": ["Runtime*"], "title": "xote"}

The repository URL and monorepo directory default to `repository`
in `package.json`.

## 3. Bundle data model (`src/core/Bundle.res`)

The bundle is one JSON file. Its types are the contract between CLI
and viewer and are the unit under test.

    type source = {file: string, line: int}

    type field = {
      name: string,
      signature: string,
      optional: bool,
      doc: string,                    docstrings joined by "\n\n"
      docCode: option<string>,        precompiled MDX function body
      deprecated: option<string>,
    }

    type constructor = {
      name: string,
      signature: string,
      doc: string,
      docCode: option<string>,
      deprecated: option<string>,
      fields: array<field>,           inline record payload, else []
    }

    type typeDetail =
      | Abstract
      | Record(array<field>)
      | Variant(array<constructor>)

    type typeRef = {name: string, id: string}

    type item = {
      id: string,                     "Xote.View.attrValue"
      anchor: string,                 "type-attrValue" / "value-attr"
      kind: kind,                     Type | Value
      name: string,
      signature: string,              verbatim from the tool
      doc: string,
      docCode: option<string>,
      deprecated: option<string>,
      source: source,
      detail: typeDetail,             Abstract for values
      refs: array<typeRef>,           name in signature -> item id
    }

    type rec module_ = {
      id: string,                     "Xote.View", "Xote.View.For"
      name: string,                   "View", "For"
      kind: moduleKind,               Module | ModuleType | Alias
      anchor: string,                 "top" or "module-For"
      doc: string,
      docCode: option<string>,
      deprecated: option<string>,
      source: source,
      types: array<item>,
      values: array<item>,
      modules: array<module_>,        nested, in source order
    }

    type bundle = {
      version: int,                   bundle format, starts at 1
      package: string,                npm name, "xote"
      packageVersion: string,         from package.json
      description: string,            one line, from package.json
      namespace: option<string>,      "Xote"
      title: string,
      hub: option<string>,            link back to the package index
      repo: option<{url: string, ref: string, dir: string}>,
      generatedAt: string,
      modules: array<module_>,        top level file modules
    }

Design choices:

- Ids are display paths, computed from nesting, because the tool's
  ids are unreliable for nested aliases (survey 3.3.4). The namespace
  prefix comes from `rescript.json`, not from `View-Xote`.
- `signature` is kept verbatim. The viewer renders it through
  `Signature.res`, which tokenizes and links identifiers using
  `refs`. `detail.parameters` from the tool is dropped as lossy.
- `refs` is resolved at build time so the viewer does no lookups
  while rendering a signature. Resolution: local module, enclosing
  modules, then the qualified index. Unresolved names stay plain
  text. `Stdlib.*` and `Dom.*` stay plain in the MVP.
- Types and values are split into two arrays because the page groups
  them that way. Source order is preserved inside each group.
- `doc` is raw markdown and `docCode` is the same text compiled to
  an MDX function body by the CLI (`@mdx-js/mdx` with GFM). The
  viewer runs the body against xote's JSX runtime and renders it
  through `Xote.Mdx`, so docstrings become xote nodes without any
  HTML injection. A docstring that is not valid MDX has no
  `docCode` and is shown as plain text.
- Everything is a plain record with only strings, ints, options and
  arrays, so the JSON codec is direct and the bundle is small (the
  xote bundle is expected around 200 KB before compression).

## 4. Search index (`src/core/Search.res`)

Built once from the bundle, in the viewer at load time and in tests.

    type entry = {
      id: string,                     "Xote.View.eachWithKey"
      name: string,                   "eachWithKey"
      lower: string,                  lowercased name for matching
      kind: Module | Type | Value,
      moduleId: string,
      signature: string,              indexed with lower weight
      href: string,
    }

Ranking is deterministic and pure, `query => array<(entry, score)>`:

| Match                                  | Score |
|----------------------------------------|-------|
| exact name                             | 100   |
| name starts with query                 | 80    |
| camelCase initials match (`ewk`)       | 60    |
| name contains query                    | 40    |
| qualified id contains query            | 30    |
| signature contains query               | 10    |
| bonus for shorter names on equal score | tie   |
| penalty for deprecated                 | -20   |

Results cap at 50. Both the ranking and the tie rules are tested.

## 5. How signals drive the viewer

    bundle: Signal.t<option<bundle>>           set once after fetch
    location = Router.location()               provided by xote
    currentModule = Computed(bundle, location) module for the route
    query: Signal.t<string>                    search input
    results = Computed(query, index)           ranked entries
    selected: Signal.t<int>                    keyboard cursor
    theme: Signal.t<theme>                     persisted to storage

Rules the components follow:

- Derived state is always a `Computed`, never a value copied into
  another signal from an effect.
- Lists are `View.For` with `by` set to the item id so that typing
  in the search box reorders result rows instead of rebuilding them.
- Components are `@xote.component`; inline reads become leaves.
- `View.tracked` is limited to small conditional regions such as
  the loading and not found states.
- The only `Effect.run` calls are for things the DOM owns: focusing
  the search input on `/`, scrolling the selected result or a deep
  link target into view, the document title and the theme.
- `Router.routes` reads the whole location signal, so it would
  rebuild the page on a hash change. The page switch reads
  `pathname`, a computed with an equality cutoff, instead.

## 6. Routes and deep links

    /                         package readme or first module
    /module/:id               module page, e.g. /module/Xote.View
    /module/:id#type-node     item anchor
    /module/:id#value-attr

Nested modules render inside their parent page with their own
anchors (`#module-For`, `#module-For-value-make`) and also get a
sidebar entry. Anchors are derived from `anchor` in the bundle. On
GitHub Pages the site is served from `/<repo>/`, passed as
`Router.init(~basePath)` and Vite `base`. `404.html` is a copy of
`index.html` so cold deep links resolve.

Source links:

    {repo.url}/blob/{repo.ref}/{repo.dir}{source.file}#L{line}

## 6b. The package index (`src/cli/Hub.res`)

`resdocs hub --out <dir>` treats every immediate subdirectory of
`<dir>` that holds a `resdocs.json` as one package, and writes
`index.html` and `logo.svg` at the root. Each card shows the
package's npm name, version, description and its module and item
counts, all read from the bundle, and links to the subdirectory. The
page is plain HTML from `src/cli/templates/hub.html` with the
palette inlined and no JavaScript, because it only links onward.

A package site knows about its index through `bundle.hub`, which
`--hub <url>` sets. The header mark links there when it is set and
to the package home otherwise, so a standalone site stays
self-contained.

Layout consequences of the hub idea:

- The header carries two identities: the product mark on the left,
  then the documented package with its version. The package name
  links to its own landing page.
- `/` is a package landing page (`PackageHome.res`) rather than a
  bare module list: name, version, description, npm and repository
  links, an install line, and a card per module with item counts.
  That is the page a reader lands on from the index.
- The sidebar lists only modules, under a heading, so it stays the
  within-package navigator.

## 7. GitHub Action (`action.yml`)

Composite action. It builds resdocs from `github.action_path`, so
nothing has to be published to npm, installs the project when it
has no `node_modules`, runs `resdocs build` (or `resdocs hub` with
`command: hub`), and with `deploy: true`
uploads with `actions/upload-pages-artifact@v5` and deploys with
`actions/deploy-pages@v5`. Defaults: `base` is `/<repo name>/`,
`repo` the current repository, `ref` the built commit. The action
versions were read from the actions' tags at implementation time.

## 8. Performance harness (`bench/bench.mjs`)

Playwright drives the built site on the xote bundle and reports:

- search latency: median and p95 of the time from `input` event to
  the results list having updated, across a scripted keystroke
  sequence
- module page render: time from `Router.push` to the page's last
  item being in the DOM, for the largest module (`Xote.XoteJSX`)

Numbers go into the README with the machine they were taken on.

## 9. Test plan

- `NormalizeTest.res`: probe fixture JSON in, bundle out, asserted
  field by field (ids, anchors, optional fields, inline records,
  deprecated, nested module paths, alias handling).
- `RefsTest.res`: local, enclosing and qualified resolution, and
  an unresolvable name staying plain.
- `SigTokensTest.res`: labels, fields, type variables, keywords.
- `SearchTest.res`: each ranking tier, tie breaking, deprecated
  penalty, cap, and empty query.
- `ViewerTest.res`: MDX docstrings with GFM and highlighting, plain
  text fallback, linked signatures and the highlighter, rendered
  through xote into jsdom via `Zekr.DomTesting`.
- `bench/smoke.mjs`: end to end in headless Chromium on the xote
  site (sidebar, module page, search keys, cold deep link, theme).

## 10. Implementation order

1. `core` types, normalizer, tests, on the probe fixture.
2. CLI end to end on xote, producing `resdocs.json`.
3. Viewer: shell, sidebar, module page, signatures with links.
4. Search with keyboard navigation, then markdown.
5. Bench harness and README numbers.
6. Action and the dogfood workflow.
