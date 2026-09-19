# API survey

Step 1 of the process: what xote 7.2.0-beta.1 and `rescript-tools doc`
actually provide, read from `node_modules` and from real tool output.
Nothing below is from memory. Every claim cites a file.

## 1. Versions and toolchain

| Package          | Version      | Note                            |
|------------------|--------------|---------------------------------|
| xote             | 7.2.0-beta.1 | dot, not dash; pinned exact     |
| rescript-signals | 3.1.3        | xote's only runtime dependency  |
| rescript         | 12.3.1       | required by xote (`^12.0.0`)    |
| zekr             | 2.1.0        | test framework                  |
| vite             | 8.3.0        |                                 |

The task said `7.2.0-beta-1`. The published version is `7.2.0-beta.1`
(`npm view xote versions`). `package.json` pins it exactly.

### The doc tool that works

`@rescript/tools@0.6.6` on npm depends on `rescript@11` and reads
ReScript 11 build artifacts. Against a ReScript 12 build it exits 0
and prints nothing. ReScript 12 ships its own copy:

    node_modules/@rescript/linux-x64/bin/rescript-tools.exe   (0.6.4)

That binary reads the 12.x `.cmt` files and produces the JSON below.
The CLI must resolve this platform binary (`@rescript/<platform>`)
instead of the `rescript-tools` shim in `.bin`. The `@rescript/tools`
package is not needed at all; it will be removed from devDependencies.

The tool needs a compiled project: it walks up from the `.res` file
to the nearest `rescript.json` and reads `lib/bs`. Compiling this
repo (which depends on `xote` and `rescript-signals`) compiles both
packages in place, so `rescript-tools doc node_modules/xote/src/X.res`
works after one `rescript build`. Running it over all 25 xote source
files takes 0.4 s in total.

## 2. xote 7.2.0-beta.1 public API

Source of truth: `node_modules/xote/AGENTS.md` lines 70 to 120 state
that the public API is exactly what the `.resi` files in `src/`
declare. Fifteen modules are public. `rescript.json` sets
`namespace: true`, so consumers refer to `Xote.View`, `Xote.Signal`,
and so on. Anything prefixed `Runtime` is internal.

Consumer configuration, mirrored in this repo's `rescript.json`:

    "dependencies": ["xote", "rescript-signals"],
    "jsx": {"version": 4, "module": "XoteJSX"},
    "ppx-flags": ["xote/ppx/ppx"]

The PPX binary for linux-x64 is present at `node_modules/xote/ppx/ppx`
(copied by `ppx/postinstall.js`), and a build with the flag succeeded.

### 2.1 Signals

Files: `src/Signal.resi`, `src/Computed.resi`, `src/Effect.resi`.

Thin re-export shims over rescript-signals. `Signal.t<'a>` is
abstract.

    Signal.make: ('a, ~name=?, ~equals=?) => t<'a>
    Signal.get / peek: t<'a> => 'a      get subscribes, peek does not
    Signal.set: (t<'a>, 'a) => unit
    Signal.update: (t<'a>, 'a => 'a) => unit
    Signal.batch: (unit => 'a) => 'a
    Signal.untrack: (unit => 'a) => 'a
    Computed.make: (unit => 'a, ~name=?, ~equals=?) => Signal.t<'a>
    Computed.dispose: Signal.t<'a> => unit
    Effect.run: (unit => option<unit => unit>, ~name=?) => unit
    Effect.runWithDisposer: (...) => {dispose: unit => unit}

Semantics that matter for this project (AGENTS.md lines 122 to 139):

- `Signal.set` uses `===` by default. Arrays and records always
  propagate unless `~equals` is passed.
- A `Computed` has no default equality cutoff. Pass `~equals` when
  downstream should ignore equal recomputations (search results that
  did not change, for instance).
- Computeds are lazy: dirty on push, recomputed on read.
- Computeds a consumer creates are never auto disposed. Computeds the
  library allocates to back a node are released with the node.
- Effects created during a component render are owned by that render
  region and disposed with it.

### 2.2 View (`src/View.resi`)

The node type:

    type rec node =
      | Element({tag, attrs, events, children})
      | Text(string)
      | SignalText(Signal.t<string>)
      | Fragment(array<node>)
      | SignalFragment(Signal.t<array<node>>)
      | Keyed({key, identity, child})
      | LazyComponent(unit => node)
      | KeyedList({signal, keyFn, renderItem})

Constructors used by the viewer:

    View.text, signalText(unit => string), int, fragment
    View.tracked: (unit => node) => node       small reactive blocks
    View.each / eachWithKey                    function-style lists
    View.render: (MaybeSignal.t<'a>, 'a => node) => node
    View.element: (tag, ~attrs=?, ~events=?, ~children=?, unit) => node
    View.null / View.empty
    View.mount: (node, Dom.element) => unit
    View.mountById: (node, string) => unit

Attribute helpers, all returning `(string, attrValue)`:

    View.attr, signalAttr, computedAttr
    View.optionalAttr, optionalSignalAttr, optionalComputedAttr

`None` from an optional helper removes the attribute, which is how
`aria-current`, `data-active` and similar presence attributes work.

JSX components (typed props, take `MaybeSignal.t`):

    <View.For each={MaybeSignal.t<array<'item>>} by=?
              render={'item => node} />
    <View.KeyedFor ... by is required />
    <View.Show when_={MaybeSignal.t<bool>} fallback=?>
      children
    </View.Show>
    <View.Maybe value={MaybeSignal.t<option<'v>>} render fallback=? />
    <View.Value value={MaybeSignal.t<'v>} render />
    <View.Text value=? > children </View.Text>   also Int, Float, Bool

`View.child: 'a => node` and `View.probe` exist for the PPX.

There is no `innerHTML` or `dangerouslySetInnerHTML` anywhere in
`src/` (`grep -i innerhtml src/*.res*` finds nothing). Rendered
markdown therefore has to be built as xote nodes, not injected as a
string. See section 4.

### 2.3 Html (`src/Html.resi`)

`div, span, button, input, h1, h2, h3, p, ul, li, a`, each
`(~attrs=?, ~events=?, ~children=?, unit) => node`. Everything else
goes through `View.element` or JSX.

### 2.4 XoteJSX (`src/XoteJSX.res`, no `.resi`)

Lowercase tags go through `XoteJSX.Elements`. Element props are
untyped: a prop accepts a raw value, a `Signal.t`, a `unit => 'a`
thunk or a `MaybeSignal.t`, normalized at runtime by
`MaybeSignal.ofUnknown` (`src/MaybeSignal.resi`). Typed props of
interest (AGENTS.md lines 152 to 175): `id, class, style, title,
href, target, role, tabIndex, ariaLabel, ariaExpanded, ariaSelected,
hidden, type_, value, placeholder, autofocus`, the `data` dict, and
the `attrs` escape hatch for anything else (`aria-current`,
`aria-controls`). Events: `onClick, onInput, onKeyDown, onKeyUp,
onFocus, onBlur, onMouseDown, onMouseEnter, onMouseLeave, onSubmit`
and more.

### 2.5 MaybeSignal (`src/MaybeSignal.resi`)

    type t<'a> = Reactive(Signal.t<'a>) | Static('a)
    static, reactive, computed(unit => 'a), fold, get, peek, map,
    toSignal, ofUnknown

`Prop` is the deprecated alias; not used here.

### 2.6 Router (`src/Router.resi`, `src/Route.resi`)

    type location = {pathname, search, hash}
    Router.location: unit => Signal.t<location>
    Router.init: (~basePath=?, unit) => unit
    Router.push / replace: (string, ~search=?, ~hash=?, unit) => unit
    Router.route: (pattern, Route.params => node) => node
    Router.routes: array<{pattern, render}> => node
    <Router.Link to class=? id=? ariaLabel=? attrs=? onClick=?>
    Route.match: (pattern, pathname) => Match(Dict.t<string>) | NoMatch

Facts checked in `src/Route.res` and `src/Router.res`:

- Patterns are `/literal/:param` segments only. There is no wildcard
  or splat segment and segment counts must match exactly
  (`Route.res` lines 35 to 39). A module path such as `Xote.View`
  contains no slash, so `/module/:path` fits.
- `push` and `replace` accept `~hash`, and after navigation the
  router scrolls the element whose id matches the hash into view
  (`Router.res` lines 176 to 192). This is what item deep links need.
- `basePath` support exists for GitHub Pages project sites
  (`Router.res` line 255). Hash-based routing does not exist, so a
  Pages deployment needs the `404.html` copy of `index.html` trick
  for cold deep links. That is a build step, not a router feature.
- Router state is a global singleton on `globalThis`.

### 2.7 The `@xote.component` PPX (`ppx/README.md`)

One annotation per component file, decomposes JSX into fine-grained
reactive leaves. Rules that shape the viewer code:

- An attribute or bare child that reads a signal inline becomes a
  reactive leaf. Hoisting the read into a plain `let` makes it a
  one-shot read (README "Known limitations").
- `if`/`switch` in child position is wrapped in `View.tracked`,
  tracking only the scrutinee.
- User component props are never thunked. Pass the signal itself for
  a reactive prop.
- One component per module (it emits `@jsx.component`).
- Semantics are "not frozen" (README "Not settled yet"). The viewer
  will use it for the showcase, but the reactive plumbing will not
  depend on anything listed there as open.

### 2.8 Not used

`SSR`, `SSRContext`, `SSRState`, `Hydration` (SSR is a non-goal),
`Mdx` (needs the MDX runtime, we render docstrings ourselves).

## 3. `rescript-tools doc` JSON, derived from real output

Files inspected, all under `docs/survey/`:

- `xote-View.json` (39 items: 10 modules, 2 types, 27 values)
- `xote-Router.json` (nested `Link` module with a module alias)
- `rescript-signals-Signal.json`
- `probe.json`, generated from `fixtures/probe/Probe.res`, which
  exercises docstrings, optional record fields, inline record
  constructors, labeled and optional arguments, `@deprecated`,
  nested modules, module types and module aliases.

`@rescript/tools` also ships a ReScript decoder,
`node_modules/@rescript/tools/npm/Tools_Docgen.res`. The real output
matches it, with the exceptions noted below. We will write our own
types from the output and keep that file as a cross-check.

### 3.1 Top level

    {
      "name": "View-Xote",       file module, namespace suffixed
      "docstrings": [...],       only from /*** */ comments
      "deprecated": null | string,
      "source": {"filepath": "src/View.resi", "line": 1, "col": 1},
      "items": [...]
    }

`name` is the compiler's internal name: `View-Xote` for a file in a
package with `namespace: true`, `Signal-Signals` for a package with
`namespace: "Signals"`, and a bare `Probe` without a namespace. The
display name (`Xote.View`) is ours to compute from `rescript.json`.

`filepath` is relative to the package root and points at the `.resi`
when one exists. `line`/`col` are 1-based.

### 3.2 Items

Every item has `id`, `kind`, `name`, `docstrings: array<string>`,
`source` and an optional `deprecated: string`.

`kind: "value"`:

    "signature": "let element: (\n  string,\n  ~attrs: ...) => node"
    "detail": {"kind": "signature", "details": {
       "parameters"?: [typeInSignature],    absent for non-functions
       "returnType": typeInSignature }}

`kind: "type"`:

    "signature": "type attrValue = Xote.RuntimeNode.attrValue = ..."
    "detail"?:
      {"kind": "record",  "items": [field]}
      {"kind": "variant", "items": [constructor]}
    (absent for abstract types and aliases such as `type t = string`)

    field       = {name, optional: bool, docstrings, signature,
                   deprecated?}
    constructor = {name, docstrings, signature, deprecated?,
                   payload?: {"kind": "inlineRecord",
                              "fields": [field]}}

An optional record field `count?: int` has `optional: true` and
`signature: "option<int>"`.

`kind: "module"`, `"moduleType"`, `"moduleAlias"`:

    {id, name, kind, docstrings, source, items: [item]}

A module alias has `items: []`. The decoder's `moduletypeid` field
never appears in the output.

`typeInSignature = {path: string, genericTypeParameters?: [...]}`.

### 3.3 Facts that drive the data model

1. Docstrings come only from `/** */` comments, and a `/*** */`
   comment gives the module docstring. Both xote and rescript-signals
   use plain `/* */` comments everywhere, so every `docstrings` array
   in their output is empty (checked across 15 files). The rendered
   docstrings feature is testable only against the probe fixture
   until those libraries convert their comments. Both are yours, so
   this is raised as a decision rather than a blocker: see the end of
   this document.

2. `detail.parameters` is lossy. Labels are dropped, an optional
   argument appears as `option<...>`, and a function-typed parameter
   `conf => shape` is flattened into two entries (`probe.json`,
   item `run`). The `signature` string is the only faithful
   rendering. Cross-references will be built by tokenizing the
   signature string and resolving identifiers; `parameters` and
   `returnType` are kept only as hints.

3. Type paths are scope relative. Inside `View-Xote`, its own types
   appear as `node` and `attrValue`; other modules appear fully
   qualified through the namespace: `Xote.Signal.t`,
   `Xote.MaybeSignal.t`, `Signals.Signal.t`, `Stdlib.Dict.t`,
   `Dom.element`. Resolution order is therefore: current module,
   enclosing modules, then the bundle-wide qualified index.

4. Nested module alias ids are wrong. `Router.Link.Prop` is emitted
   with `id: "Router-Xote.Prop"` (`xote-Router.json`). Ids cannot be
   trusted as paths; the normalizer computes the path from nesting.

5. `signature` for a type that re-exports another
   (`type attrValue = Xote.RuntimeNode.attrValue = | ...`) names the
   original. The equation form is preserved verbatim.

6. A `.resi` narrows the output to the interface. `RuntimeNode.res`
   (no interface) documents everything in the file. The CLI will
   document every `.res` in the configured source dirs and let a
   package opt modules out by name.

## 4. Gaps and decisions for you

1. Markdown rendering. xote cannot inject HTML, and the stack lists no
   markdown library. Proposal: `mdast-util-from-markdown` plus
   `mdast-util-gfm` (JS, ESM, no DOM), bound in ReScript as an mdast
   AST, rendered to xote nodes by a small `Markdown.res`. Alternative:
   a hand-written CommonMark subset in ReScript, which is more code
   and less correct. Which do you prefer?

2. Docstrings in xote and rescript-signals are empty because they use
   `/* */`. The generator will work and the dogfood sites will show
   full signatures, types and source links, but no prose until the
   comments become `/** */`. Do you want a warning in the CLI output
   listing undocumented public items?

3. The doc binary is the one inside `@rescript/<platform>`, which
   `rescript` depends on. The CLI will locate it through
   `require.resolve("rescript/package.json")`. Confirm you are fine
   with this over `@rescript/tools`.

4. GitHub Pages deep links. `Router` has path routing with a base
   path but no hash routing. The build will emit `404.html` as a copy
   of `index.html` so cold loads of `/repo/module/Xote.View#text`
   work on Pages. Fine by you?

5. The task lists `rescript-signals` as a direct dependency. Since
   xote re-exports `Signal`, `Computed` and `Effect`, the viewer will
   use `Xote.Signal` and friends and keep `rescript-signals` only as
   a ReScript dependency for compilation (xote requires it).
