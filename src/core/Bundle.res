/* The normalized bundle: the contract between the CLI and the
   viewer. One JSON file per package. Every field is a string, int,
   bool, option or array, so the JSON codec is the identity. */

type source = {file: string, line: int}

type field = {
  name: string,
  signature: string,
  optional: bool,
  doc: string,
  docCode: option<string>,
  deprecated: option<string>,
}

type constructor = {
  name: string,
  signature: string,
  doc: string,
  docCode: option<string>,
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
  docCode: option<string>,
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
  docCode: option<string>,
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

let version = 1

external fromJson: JSON.t => bundle = "%identity"

let parse = (text: string): bundle => JSON.parseOrThrow(text)->fromJson

let stringify = (bundle: bundle): string =>
  JSON.stringifyAny(bundle)->Option.getOr("{}")

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
