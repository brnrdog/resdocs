/* The normalized bundle: the contract between the CLI and the
   viewer. One JSON file per package. Every field is a string, int,
   bool, option or array, so the JSON codec is the identity. */

type source = {file: string, line: int}

type field = {
  name: string,
  signature: string,
  optional: bool,
  doc: string,
  docTree: option<array<Doc.node>>,
  deprecated: option<string>,
}

type constructor = {
  name: string,
  signature: string,
  doc: string,
  docTree: option<array<Doc.node>>,
  deprecated: option<string>,
  fields: array<field>,
}

@tag("kind")
type typeDetail =
  | @as("abstract") Abstract
  | @as("record") Record({fields: array<field>})
  | @as("variant") Variant({constructors: array<constructor>})

type kind =
  | @as("type") Type
  | @as("value") Value

/* A name as it appears in a signature and the id it resolves to. */
type typeRef = {name: string, id: string}

type item = {
  id: string,
  anchor: string,
  kind: kind,
  name: string,
  signature: string,
  doc: string,
  docTree: option<array<Doc.node>>,
  deprecated: option<string>,
  source: source,
  detail: typeDetail,
  refs: array<typeRef>,
}

type moduleKind =
  | @as("module") Module
  | @as("moduleType") ModuleType
  | @as("alias") Alias

type rec module_ = {
  id: string,
  name: string,
  kind: moduleKind,
  anchor: string,
  doc: string,
  docTree: option<array<Doc.node>>,
  deprecated: option<string>,
  source: source,
  types: array<item>,
  values: array<item>,
  modules: array<module_>,
}

type repo = {url: string, ref: string, dir: string}

type bundle = {
  version: int,
  package: string,
  packageVersion: string,
  description: string,
  namespace: option<string>,
  title: string,
  hub: option<string>,
  repo: option<repo>,
  generatedAt: string,
  modules: array<module_>,
}

let version = 2

external fromJson: JSON.t => bundle = "%identity"

let parse = (text: string): bundle => JSON.parseOrThrow(text)->fromJson

/* What the viewer reads: the bundle, or a sentence for the reader
   saying why it cannot be shown. A viewer only renders the format it
   was built with, so a mismatch is an error rather than a page that
   fails halfway. */
let decode = (text: string): result<bundle, string> =>
  switch JSON.parseOrThrow(text) {
  | exception _ => Error("resdocs.json is not valid JSON.")
  | json =>
    switch json
    ->JSON.Decode.object
    ->Option.flatMap(o => o->Dict.get("version"))
    ->Option.flatMap(JSON.Decode.float) {
    | Some(v) if v == Int.toFloat(version) => Ok(fromJson(json))
    | Some(v) =>
      Error(
        `resdocs.json uses bundle format ${Float.toString(v)}, but this viewer reads format ${Int.toString(
            version,
          )}. Rebuild the site with a single version of resdocs.`,
      )
    | None => Error("resdocs.json has no bundle format version.")
    }
  }

let stringify = (bundle: bundle): string =>
  JSON.stringifyAny(bundle)->Option.getOr("{}")

/* The first sentence of a docstring's first line: a module's summary
   on the package page and in its page's meta description. */
let firstSentence = (doc: string): string => {
  let line = doc->String.split("\n")->Array.get(0)->Option.getOr("")
  switch line->String.indexOf(". ") {
  | -1 => line
  | i => line->String.slice(~start=0, ~end=i + 1)
  }
}

/* Every module in the bundle, depth first, parents before children. */
let allModules = (bundle: bundle): array<module_> => {
  let out = []
  let rec walk = (m: module_) => {
    out->Array.push(m)
    m.modules->Array.forEach(walk)
  }
  bundle.modules->Array.forEach(walk)
  out
}

let findModule = (bundle: bundle, id: string): option<module_> =>
  allModules(bundle)->Array.find(m => m.id == id)

/* The top level module an id belongs to: "Xote.View.For.props" is
   inside "Xote.View" when the bundle has that module. */
let topModuleOf = (bundle: bundle, id: string): option<module_> =>
  bundle.modules->Array.find(m => id == m.id || id->String.startsWith(m.id ++ "."))

/* GitHub blob link for a source location, when a repo is configured. */
let sourceUrl = (bundle: bundle, source: source): option<string> =>
  bundle.repo->Option.map(repo => {
    let dir = repo.dir == "" ? "" : repo.dir ++ "/"
    `${repo.url}/blob/${repo.ref}/${dir}${source.file}#L${Int.toString(source.line)}`
  })
