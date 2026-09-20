/* All viewer state. Sources are signals, everything derived is a
   Computed, and the components only read. See docs/design.md
   section 5. */

open Xote

/* ------------------------------------------------------------ base url */

/* Injected by the CLI into index.html. In dev the placeholder is still
   there, which means "/". */
let base: string = switch Browser.rawBase->Nullable.toOption {
| Some(b) if !(b->String.includes("__RESDOCS_BASE__")) => b
| _ => "/"
}

/* The router wants the base without its trailing slash. */
let routerBase: string = base == "/" ? "/" : base->String.slice(~start=0, ~end=String.length(base) - 1)

/* --------------------------------------------------------------- bundle */

let bundle: Signal.t<option<Bundle.bundle>> = Signal.make(None, ~name="bundle")

let loaded = Computed.make(() => Signal.get(bundle)->Option.isSome, ~equals=(a, b) => a == b)

let title = Computed.make(
  () => Signal.get(bundle)->Option.mapOr("resdocs", b => b.title),
  ~equals=(a, b) => a == b,
)

let topModules = Computed.make(() => Signal.get(bundle)->Option.mapOr([], b => b.modules))

let moduleMap = Computed.make(() => {
  let dict = Dict.make()
  Signal.get(bundle)
  ->Option.mapOr([], Bundle.allModules)
  ->Array.forEach(m => dict->Dict.set(m.id, m))
  dict
})

/* Where an id can be found: its top level module page and anchor. */
type target = {moduleId: string, anchor: string}

let targets = Computed.make(() => {
  let dict = Dict.make()
  Signal.get(bundle)
  ->Option.mapOr([], b => b.modules)
  ->Array.forEach(top => {
    let rec walk = (m: Bundle.module_) => {
      dict->Dict.set(m.id, {moduleId: top.id, anchor: m.anchor})
      m.types->Array.concat(m.values)->Array.forEach(i => dict->Dict.set(i.id, {moduleId: top.id, anchor: i.anchor}))
      m.modules->Array.forEach(walk)
    }
    walk(top)
  })
  dict
})

let pathOf = (target: target): string =>
  "/module/" ++ target.moduleId ++ (target.anchor == "top" ? "" : "#" ++ target.anchor)

/* App relative path for an item or module id, when the bundle has it. */
let hrefOf = (id: string): option<string> =>
  Signal.peek(targets)->Dict.get(id)->Option.map(pathOf)

let index = Computed.make(() => Signal.get(bundle)->Option.mapOr([], Search.build))

@val external decodeURIComponent: string => string = "decodeURIComponent"

/* --------------------------------------------------------------- routing */

let pathname = Computed.make(
  () => Signal.get(Router.location()).pathname,
  ~name="pathname",
  ~equals=(a, b) => a == b,
)

type page =
  | HomePage
  | ModulePage
  | NotFoundPage

let modulePrefix = "/module/"

let currentModuleId = Computed.make(
  () => {
    let p = Signal.get(pathname)
    p->String.startsWith(modulePrefix)
      ? Some(p->String.slice(~start=String.length(modulePrefix))->decodeURIComponent)
      : None
  },
  ~equals=(a, b) => a == b,
)

let page = Computed.make(
  () =>
    switch Signal.get(pathname) {
    | "/" | "" => HomePage
    | _ => Signal.get(currentModuleId)->Option.isSome ? ModulePage : NotFoundPage
    },
  ~equals=(a, b) => a == b,
)

let currentModule = Computed.make(
  () =>
    switch Signal.get(currentModuleId) {
    | Some(id) => Signal.get(moduleMap)->Dict.get(id)
    | None => None
    },
  ~name="currentModule",
  ~equals=(a, b) => a === b,
)

/* ---------------------------------------------------------------- search */

let query = Signal.make("", ~name="query")
let selected = Signal.make(0, ~name="selected")

let results = Computed.make(() => Search.search(Signal.get(index), Signal.get(query)), ~name="results")

let selectedId = Computed.make(
  () => Signal.get(results)->Array.get(Signal.get(selected))->Option.map(e => e.id),
  ~equals=(a, b) => a == b,
)

let setQuery = (q: string) =>
  Signal.batch(() => {
    Signal.set(query, q)
    Signal.set(selected, 0)
  })

let moveSelection = (delta: int) => {
  let count = Signal.peek(results)->Array.length
  if count > 0 {
    let next = Signal.peek(selected) + delta
    Signal.set(selected, next < 0 ? count - 1 : mod(next, count))
  }
}

let navigateTo = (entry: Search.entry) => {
  let hash = entry.anchor == "top" ? "" : "#" ++ entry.anchor
  Router.push("/module/" ++ entry.moduleId, ~hash, ())
  setQuery("")
}

let submit = () =>
  switch Signal.peek(results)->Array.get(Signal.peek(selected)) {
  | Some(entry) => navigateTo(entry)
  | None => ()
  }

/* ----------------------------------------------------------------- theme */

type theme =
  | Light
  | Dark

let initialTheme = () =>
  switch Browser.readStorage("resdocs-theme") {
  | Some("dark") => Dark
  | Some("light") => Light
  | _ =>
    try Browser.matchMedia("(prefers-color-scheme: dark)").matches ? Dark : Light catch {
    | _ => Light
    }
  }

let theme = Signal.make(initialTheme(), ~name="theme")

let themeName = (t: theme) =>
  switch t {
  | Light => "light"
  | Dark => "dark"
  }

let toggleTheme = () =>
  Signal.update(theme, t =>
    switch t {
    | Light => Dark
    | Dark => Light
    }
  )
