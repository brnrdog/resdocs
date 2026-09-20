/* Reads a ReScript project's rescript.json and lists the source files
   to document. Dev sources (tests, examples) are skipped. */

type sourceDir = {dir: string, subdirs: bool}

type t = {
  dir: string,
  name: string,
  sources: array<sourceDir>,
}

let decodeSource = (json: JSON.t): option<sourceDir> =>
  switch json {
  | String(dir) => Some({dir, subdirs: false})
  | Object(o) =>
    let isDev = switch o->Dict.get("type")->Option.flatMap(JSON.Decode.string) {
    | Some("dev") => true
    | _ => false
    }
    let dir = o->Dict.get("dir")->Option.flatMap(JSON.Decode.string)
    let subdirs = switch o->Dict.get("subdirs") {
    | Some(v) => JSON.Decode.bool(v)->Option.getOr(true)
    | None => false
    }
    switch (isDev, dir) {
    | (false, Some(dir)) => Some({dir, subdirs})
    | _ => None
    }
  | _ => None
  }

let decodeSources = (json: option<JSON.t>): array<sourceDir> =>
  switch json {
  | Some(Array(items)) => items->Array.filterMap(decodeSource)
  | Some(_) => json->Option.flatMap(decodeSource)->Option.mapOr([], s => [s])
  | None => []
  }

let load = (dir: string): result<t, string> => {
  let file = Node.join([dir, "rescript.json"])
  if !Node.existsSync(file) {
    Error("no rescript.json in " ++ dir)
  } else {
    switch JSON.parseOrThrow(Node.readFileSync(file))->JSON.Decode.object {
    | None => Error("rescript.json is not an object")
    | Some(o) =>
      let name =
        o
        ->Dict.get("name")
        ->Option.flatMap(JSON.Decode.string)
        ->Option.getOr(Node.basename(dir))
      Ok({dir, name, sources: decodeSources(o->Dict.get("sources"))})
    }
  }
}

let rec walk = (dir: string, ~subdirs: bool, out: array<string>) =>
  if Node.existsSync(dir) {
    Node.readdirSync(dir)
    ->Array.toSorted(String.compare)
    ->Array.forEach(entry => {
      let full = Node.join([dir, entry])
      if Node.statSync(full)->Node.isDirectory {
        if subdirs && !(entry->String.startsWith(".")) && entry != "node_modules" {
          walk(full, ~subdirs, out)
        }
      } else if entry->String.endsWith(".res") {
        out->Array.push(full)
      }
    })
  }

/* Absolute paths of every .res file under the project's sources. */
let sourceFiles = (project: t): array<string> => {
  let out = []
  project.sources->Array.forEach(s => walk(Node.join([project.dir, s.dir]), ~subdirs=s.subdirs, out))
  out
}

let moduleNameOf = (file: string): string => Node.basename(file)->String.replace(".res", "")

/* Repository metadata from package.json, when present. */
type repository = {url: string, dir: string}

let normalizeRepoUrl = (raw: string): string => {
  let s = raw
  let s = s->String.startsWith("github:") ? "https://github.com/" ++ s->String.slice(~start=7) : s
  let s = s->String.startsWith("git+") ? s->String.slice(~start=4) : s
  let s = s->String.startsWith("git@github.com:") ? "https://github.com/" ++ s->String.slice(~start=15) : s
  let s = s->String.endsWith(".git") ? s->String.slice(~start=0, ~end=String.length(s) - 4) : s
  s->String.endsWith("/") ? s->String.slice(~start=0, ~end=String.length(s) - 1) : s
}

let repository = (dir: string): option<repository> => {
  let file = Node.join([dir, "package.json"])
  if !Node.existsSync(file) {
    None
  } else {
    JSON.parseOrThrow(Node.readFileSync(file))
    ->JSON.Decode.object
    ->Option.flatMap(o => o->Dict.get("repository"))
    ->Option.flatMap(repo =>
      switch repo {
      | String(url) => Some({url: normalizeRepoUrl(url), dir: ""})
      | Object(o) =>
        o
        ->Dict.get("url")
        ->Option.flatMap(JSON.Decode.string)
        ->Option.map(url => {
          url: normalizeRepoUrl(url),
          dir: o->Dict.get("directory")->Option.flatMap(JSON.Decode.string)->Option.getOr(""),
        })
      | _ => None
      }
    )
  }
}
