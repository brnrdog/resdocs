# Repo layout and data model

Step 2 of the process. Builds on `docs/api-survey.md`.

## 1. Repo layout

One npm package, one ReScript project, three source roots. The CLI
and the viewer share the bundle types so a change in the JSON shape
breaks both at compile time.

    resdocs/
      package.json           bin: resdocs, scripts: build, test, bench
      rescript.json          sources: src, tests; jsx XoteJSX; ppx
      vite.config.mjs        root: viewer/, base from env
      index.html             Vite entry, mounts the SPA
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
        cli/
          Cli.res            entry: parse args, run pipeline, write
          Project.res        read rescript.json, list source files
          Tools.res          locate and run rescript-tools.exe
          NodeBindings.res   fs, path, child_process externals
        viewer/
          Main.res           mount, Router.init, theme init
          Store.res          bundle signal, route derived signals
          Markdown.res       mdast bindings and node renderer
          Signature.res      signature tokenizer with type links
          components/
            App.res          layout shell, routes
            Sidebar.res      module tree, View.For over nested nodes
            ModulePage.res   sections: types, values, submodules
            ItemCard.res     one type or value, anchored
            Search.res       input, results, keyboard navigation
            ThemeToggle.res
          styles.css
      tests/
        Normalize.test.res   Zekr, fixture driven
        Search.test.res      Zekr, ranking assertions
        Refs.test.res
        Markdown.test.res
        fixtures/
          probe/             the probe package and its expected JSON
      bench/
        bench.mjs            Playwright: search latency, page render
      examples/
        xote/                dogfood config for xote
        rescript-signals/    dogfood config for rescript-signals
      .github/workflows/
        ci.yml               build, test, bench on the xote bundle
        docs.yml             dogfood: build both sites, deploy Pages

Notes on the split:

- `src/core` compiles to ESM that runs in both Node and the browser.
  It must not reference `Dom` or `process`.
- `src/cli` is Node only. It never imports xote.
- `src/viewer` is browser only. It reads the bundle over `fetch`.
- Tests live in `tests/` with the `.test.res` suffix so `zekr`
  discovers them. `rescript.json` marks `tests` as `type: dev`.

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

Config can also come from `resdocs.json` in the project root so the
Action needs no arguments:

    {"repo": "https://github.com/brnrdog/xote", "ref": "main",
     "dir": "", "exclude": ["Runtime*"], "title": "xote"}

## 3. Bundle data model (`src/core/Bundle.res`)

The bundle is one JSON file. Its types are the contract between CLI
and viewer and are the unit under test.

    type source = {file: string, line: int}

    type field = {
      name: string,
      signature: string,
      optional: bool,
      doc: string,                    docstrings joined by "\n\n"
      deprecated: option<string>,
    }

    type constructor = {
      name: string,
      signature: string,
      doc: string,
      deprecated: option<string>,
      fields: array<field>,           inline record payload, else []
    }

    type typeDetail =
      | Abstract
      | Record(array<field>)
      | Variant(array<constructor>)

    type item = {
      id: string,                     "Xote.View.attrValue"
      anchor: string,                 "type-attrValue" / "value-attr"
      kind: kind,                     Type | Value
      name: string,
      signature: string,              verbatim from the tool
      doc: string,
      deprecated: option<string>,
      source: source,
      detail: typeDetail,             Abstract for values
      refs: array<string>,            resolved ids the signature names
    }

    type rec module_ = {
      id: string,                     "Xote.View", "Xote.View.For"
      name: string,                   "View", "For"
      kind: moduleKind,               Module | ModuleType | Alias
      doc: string,
      deprecated: option<string>,
      source: source,
      types: array<item>,
      values: array<item>,
      modules: array<module_>,        nested, in source order
    }

    type bundle = {
      version: int,                   bundle format, starts at 1
      package: string,                "xote"
      namespace: option<string>,      "Xote"
      title: string,
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
- `doc` is raw markdown. Rendering happens in the viewer.
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
  the empty state of the results list.
- The only `Effect.run` calls are for things the DOM owns: focusing
  the search input on `/`, scrolling the selected result into view,
  and persisting the theme.

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

## 7. GitHub Action (`action.yml`)

Composite action with inputs `project` (default `.`), `repo`
(default `github.repository` URL), `ref` (default `github.sha`),
`base` (default `/<repo name>/`). Steps: setup Node, install, run
`resdocs build`, upload with `actions/upload-pages-artifact`, deploy
with `actions/deploy-pages`. Exact action versions are checked at
implementation time, not assumed.

## 8. Performance harness (`bench/bench.mjs`)

Playwright drives the built site on the xote bundle and reports:

- search latency: median and p95 of the time from `input` event to
  the results list having updated, across a scripted keystroke
  sequence
- module page render: time from `Router.push` to the page's last
  item being in the DOM, for the largest module (`Xote.XoteJSX`)

Numbers go into the README with the machine they were taken on.

## 9. Test plan

- `Normalize.test.res`: probe fixture JSON in, bundle out, asserted
  field by field (ids, anchors, optional fields, inline records,
  deprecated, nested module paths, alias handling).
- `Refs.test.res`: local, enclosing and qualified resolution, and
  an unresolvable name staying plain.
- `Search.test.res`: each ranking tier, tie breaking, deprecated
  penalty, cap, and empty query.
- `Markdown.test.res`: headings, paragraphs, lists, inline code,
  fenced code, links, rendered through xote into jsdom via
  `Zekr.DomTesting`.

## 10. Implementation order

1. `core` types, normalizer, tests, on the probe fixture.
2. CLI end to end on xote, producing `resdocs.json`.
3. Viewer: shell, sidebar, module page, signatures with links.
4. Search with keyboard navigation, then markdown.
5. Bench harness and README numbers.
6. Action and the dogfood workflow.
