/* resdocs build: document a ReScript package into one bundle and a
   static site. See docs/design.md section 2. */

type command =
  | Build
  | Index

type options = {
  project: string,
  out: string,
  repo: option<string>,
  ref: option<string>,
  dir: option<string>,
  base: option<string>,
  hub: option<string>,
  title: option<string>,
  tagline: option<string>,
  exclude: array<string>,
  bundleOnly: bool,
  strict: bool,
  command: command,
}

let defaults = {
  project: ".",
  out: "docs-site",
  repo: None,
  ref: None,
  dir: None,
  base: None,
  hub: None,
  title: None,
  tagline: None,
  exclude: [],
  bundleOnly: false,
  strict: false,
  command: Build,
}

let usage = `usage: resdocs build [options]
       resdocs hub [options]

resdocs build documents one package. resdocs hub writes an index page
over a directory of already-built packages, so one site can host the
API docs of many ReScript packages.

  --project <dir>    ReScript project to document (default: .)
  --out <dir>        output directory (default: docs-site)
  --repo <url>       GitHub repository URL for source links
  --ref <ref>        git ref for source links (default: main)
  --dir <path>       package directory inside the repository
  --base <path>      URL path the site is served from (default: /)
  --hub <url>        link back to the package index this site is part of
  --title <text>     site title (default: package name)
  --exclude <globs>  comma separated module patterns, e.g. Runtime*
  --bundle-only      write resdocs.json and skip the viewer
  --strict           fail when a public item has no docstring

hub options:

  --out <dir>        directory holding one subdirectory per package
  --base <path>      URL path the index is served from (default: /)
  --title <text>     index heading (default: ReScript API docs)
  --tagline <text>   one line under the heading

Options may also come from resdocs.config.json in the project.`

let parseArgs = (argv: array<string>): result<options, string> => {
  let opts = ref(defaults)
  let error = ref(None)
  let i = ref(0)
  let next = flag =>
    switch argv->Array.get(i.contents + 1) {
    | Some(v) =>
      i := i.contents + 1
      v
    | None =>
      error := Some("missing value for " ++ flag)
      ""
    }
  while i.contents < Array.length(argv) && error.contents == None {
    let arg = argv->Array.getUnsafe(i.contents)
    switch arg {
    | "build" => opts := {...opts.contents, command: Build}
    | "hub" | "index" => opts := {...opts.contents, command: Index}
    | "--project" => opts := {...opts.contents, project: next(arg)}
    | "--out" => opts := {...opts.contents, out: next(arg)}
    | "--repo" => opts := {...opts.contents, repo: Some(next(arg))}
    | "--ref" => opts := {...opts.contents, ref: Some(next(arg))}
    | "--dir" => opts := {...opts.contents, dir: Some(next(arg))}
    | "--base" => opts := {...opts.contents, base: Some(next(arg))}
    | "--hub" => opts := {...opts.contents, hub: Some(next(arg))}
    | "--title" => opts := {...opts.contents, title: Some(next(arg))}
    | "--tagline" => opts := {...opts.contents, tagline: Some(next(arg))}
    | "--exclude" =>
      opts := {...opts.contents, exclude: next(arg)->String.split(",")->Array.map(String.trim)}
    | "--bundle-only" => opts := {...opts.contents, bundleOnly: true}
    | "--strict" => opts := {...opts.contents, strict: true}
    | "-h" | "--help" => error := Some(usage)
    | other => error := Some("unknown argument " ++ other ++ "\n\n" ++ usage)
    }
    i := i.contents + 1
  }
  switch error.contents {
  | Some(e) => Error(e)
  | None => Ok(opts.contents)
  }
}

/* resdocs.config.json fills in whatever the command line left unset. */
let withConfigFile = (opts: options, projectDir: string): options => {
  let file = Node.join([projectDir, "resdocs.config.json"])
  if !Node.existsSync(file) {
    opts
  } else {
    switch JSON.parseOrThrow(Node.readFileSync(file))->JSON.Decode.object {
    | None => opts
    | Some(o) =>
      let str = key => o->Dict.get(key)->Option.flatMap(JSON.Decode.string)
      let orConfig = (current, key) =>
        switch current {
        | Some(_) => current
        | None => str(key)
        }
      {
        ...opts,
        repo: orConfig(opts.repo, "repo"),
        ref: orConfig(opts.ref, "ref"),
        dir: orConfig(opts.dir, "dir"),
        base: orConfig(opts.base, "base"),
        hub: orConfig(opts.hub, "hub"),
        title: orConfig(opts.title, "title"),
        tagline: orConfig(opts.tagline, "tagline"),
        strict: opts.strict ||
          o->Dict.get("strict")->Option.flatMap(JSON.Decode.bool)->Option.getOr(false),
        exclude: Array.length(opts.exclude) > 0
          ? opts.exclude
          : o
            ->Dict.get("exclude")
            ->Option.flatMap(JSON.Decode.array)
            ->Option.mapOr([], a => a->Array.filterMap(JSON.Decode.string)),
      }
    }
  }
}

/* The base ends up inside index.html, in attributes and an inline
   script, so it is limited to characters that need no escaping. */
let checkBase = (base: option<string>): result<unit, string> =>
  switch base {
  | Some(b) if b->String.match(/^[A-Za-z0-9._~\/-]*$/)->Option.isNone =>
    Error("--base may only contain letters, digits and . _ ~ / -, got " ++ b)
  | _ => Ok()
  }

let normalizeBase = (base: string): string => {
  let b = base->String.startsWith("/") ? base : "/" ++ base
  b->String.endsWith("/") ? b : b ++ "/"
}

/* ---------------------------------------------------------------- docs */

/* Docstrings become sanitized trees; see src/core/Doc.res. */
let parseDoc = (doc: string): option<array<Doc.node>> =>
  doc == "" ? None : Some(Doc.sanitize(Node.parseDoc(doc)))

let parseField = (f: Bundle.field): Bundle.field => {...f, docTree: parseDoc(f.doc)}

let parseConstructor = (c: Bundle.constructor): Bundle.constructor => {
  ...c,
  docTree: parseDoc(c.doc),
  fields: c.fields->Array.map(parseField),
}

let parseItem = (item: Bundle.item): Bundle.item => {
  ...item,
  docTree: parseDoc(item.doc),
  detail: switch item.detail {
  | Abstract => Abstract
  | Record({fields}) => Record({fields: fields->Array.map(parseField)})
  | Variant({constructors}) => Variant({constructors: constructors->Array.map(parseConstructor)})
  },
}

let rec parseModule = (m: Bundle.module_): Bundle.module_ => {
  ...m,
  docTree: parseDoc(m.doc),
  types: m.types->Array.map(parseItem),
  values: m.values->Array.map(parseItem),
  modules: m.modules->Array.map(parseModule),
}

/* Items without a docstring, reported per file module. */
let undocumented = (m: Bundle.module_): (int, int) => {
  let missing = ref(0)
  let total = ref(0)
  let rec walk = (m: Bundle.module_) => {
    m.types
    ->Array.concat(m.values)
    ->Array.forEach(item => {
      total := total.contents + 1
      if item.doc == "" {
        missing := missing.contents + 1
      }
    })
    m.modules->Array.forEach(walk)
  }
  walk(m)
  (missing.contents, total.contents)
}

/* ------------------------------------------------------------- pipeline */

let fail = (message: string): int => {
  Node.warn("resdocs: " ++ message)
  1
}

/* One pre-rendered page of the site. */
type page = {path: string, file: string, title: string, description: string}

let plainText = (text: string): string =>
  text->String.replaceAll("`", "")->String.replaceAll("*", "")->String.trim

/* The home page, one page per top level module (nested modules are
   sections of their parent's page), and the page for unknown paths. */
let pagesOf = (bundle: Bundle.bundle): array<page> => {
  let summary = bundle.description != ""
    ? bundle.description
    : `API documentation for ${bundle.package}.`
  let home = {path: "/", file: "index.html", title: bundle.title, description: summary}
  let modules = bundle.modules->Array.map((m): page => {
    path: "/module/" ++ m.id,
    file: Node.join(["module", m.id, "index.html"]),
    title: `${m.id} - ${bundle.title}`,
    description: switch plainText(Bundle.firstSentence(m.doc)) {
    | "" => `API reference for ${m.id} in ${bundle.package}.`
    | sentence => sentence
    },
  })
  /* GitHub Pages serves 404.html, with a 404 status, for any path
     that has no file. */
  let notFound = {
    path: "/404",
    file: "404.html",
    title: `Page not found - ${bundle.title}`,
    description: summary,
  }
  [home]->Array.concat(modules)->Array.concat([notFound])
}

let writeSite = async (~out: string, ~base: string, bundle: Bundle.bundle): result<
  int,
  string,
> => {
  let viewer = Node.join([Node.packageRoot, "dist", "viewer"])
  if !Node.existsSync(Node.join([viewer, "index.html"])) {
    Error("viewer not built at " ++ viewer ++ ", run `npm run build` in resdocs")
  } else {
    Node.copyDir(viewer, out)
    Node.writeFileSync(Node.join([out, "logo.svg"]), Hub.logoFile)
    let template =
      Node.readFileSync(Node.join([viewer, "index.html"]))->String.replaceAll(
        "/__RESDOCS_BASE__/",
        base,
      )
    let pages = pagesOf(bundle)
    let bodies = await Node.prerender(bundle, ~base, pages->Array.map(p => p.path))
    pages->Array.forEachWithIndex((page, i) => {
      let body = bodies->Array.getUnsafe(i)
      let html =
        template
        ->String.replaceAll("__RESDOCS_TITLE__", Hub.escape(page.title))
        ->String.replaceAll("__RESDOCS_DESCRIPTION__", Hub.escape(page.description))
        /* A function replacement, so `$` in the markup stays literal. */
        ->String.replaceRegExpBy0Unsafe(/<div id="app"><\/div>/, (~match as _, ~offset as _, ~input as _) =>
          `<div id="app">${body}</div>`
        )
      let file = Node.join([out, page.file])
      Node.mkdirp(Node.dirname(file))
      Node.writeFileSync(file, html)
    })
    Ok(Array.length(pages))
  }
}

/* Everything after the tool ran: the bundle and, unless
   --bundle-only, the site around it. */
let writeOutput = async (opts: options, ~project: Project.t, ~projectDir: string, docs): int => {
  let namespace = docs->Array.get(0)->Option.flatMap(Normalize.namespaceOf)
  let modules = Refs.apply(docs->Array.map(doc => Normalize.ofDoc(doc)))
  let modules = modules->Array.map(parseModule)
  let missing = modules->Array.reduce(0, (acc, m) => {
    let (missing, total) = undocumented(m)
    if missing > 0 {
      Node.warn(
        `resdocs: ${m.id}: ${Int.toString(missing)} of ${Int.toString(total)} items have no docstring`,
      )
    }
    acc + missing
  })
  if opts.strict && missing > 0 {
    fail(`--strict: ${Int.toString(missing)} items have no docstring`)
  } else {
    let repository = Project.repository(projectDir)
    let repoUrl = switch opts.repo {
    | Some(url) => Some(Project.normalizeRepoUrl(url))
    | None => repository->Option.map(r => r.url)
    }
    let repo: option<Bundle.repo> = repoUrl->Option.map(url => {
      Bundle.url,
      ref: opts.ref->Option.getOr("main"),
      dir: switch opts.dir {
      | Some(dir) => dir
      | None => repository->Option.mapOr("", r => r.dir)
      },
    })
    let title = opts.title->Option.getOr(project.name)
    let info = Project.packageInfo(projectDir)
    let bundle: Bundle.bundle = {
      version: Bundle.version,
      package: info.npmName == "" ? project.name : info.npmName,
      packageVersion: info.version,
      description: info.description,
      namespace,
      title,
      hub: opts.hub,
      repo,
      generatedAt: Node.nowIso(),
      modules,
    }
    let out = Node.resolve(Node.cwd(), opts.out)
    Node.mkdirp(out)
    Node.writeFileSync(Node.join([out, "resdocs.json"]), Bundle.stringify(bundle))
    Node.log(
      `resdocs: ${Int.toString(Array.length(modules))} modules written to ${Node.relative(
          Node.cwd(),
          out,
        )}/resdocs.json`,
    )
    if opts.bundleOnly {
      0
    } else {
      switch await writeSite(~out, ~base=normalizeBase(opts.base->Option.getOr("/")), bundle) {
      | Ok(count) =>
        Node.log(
          `resdocs: site written to ${Node.relative(Node.cwd(), out)} (${Int.toString(
              count,
            )} pages)`,
        )
        0
      | Error(e) => fail(e)
      }
    }
  }
}

let build = async (opts: options): int => {
  let projectDir = Node.resolve(Node.cwd(), opts.project)
  let opts = withConfigFile(opts, projectDir)
  switch checkBase(opts.base)->Result.flatMap(() => Project.load(projectDir)) {
  | Error(e) => fail(e)
  | Ok(project) =>
    switch await Tools.locate(projectDir) {
    | Error(e) => fail(e)
    | Ok(tools) =>
      /* Always compile: the build is incremental, and documenting a
         stale lib/bs silently describes old code or misses new files. */
      Node.log("resdocs: compiling " ++ project.name)
      switch Tools.build(tools) {
      | Error(e) => fail(e)
      | Ok() =>
        let files =
          Project.sourceFiles(project)->Array.filter(file => {
            let name = Project.moduleNameOf(file)
            !(opts.exclude->Array.some(p => Normalize.matchesPattern(p, name)))
          })
        let results = files->Array.map(file => (file, Tools.doc(tools, file)))
        let failures = results->Array.filterMap(((file, result)) =>
          switch result {
          | Error(e) => Some((file, e))
          | Ok(_) => None
          }
        )
        let count = n => Int.toString(Array.length(n))
        if Array.length(files) == 0 {
          fail(
            "no .res files in the sources of rescript.json" ++
            (Array.length(opts.exclude) > 0 ? " after --exclude" : ""),
          )
        } else if Array.length(failures) > 0 {
          failures->Array.forEach(((file, e)) =>
            Node.warn("resdocs: " ++ Node.relative(projectDir, file) ++ ": " ++ e)
          )
          fail(
            `${count(failures)} of ${count(files)} source files could not be documented. ` ++
            "Fix them, or leave them out with --exclude.",
          )
        } else {
          let docs = results->Array.filterMap(((_, result)) =>
            switch result {
            | Ok(json) => Some(Docgen.parse(json))
            | Error(_) => None
            }
          )
          await writeOutput(opts, ~project, ~projectDir, docs)
        }
      }
    }
  }
}

let writeIndex = (opts: options): int => {
  let root = Node.resolve(Node.cwd(), opts.out)
  switch checkBase(opts.base) {
  | Error(e) => fail(e)
  | Ok() if !Node.existsSync(root) =>
    fail("no such directory: " ++ opts.out)
  | Ok() =>
    let count = Hub.write(
      ~root,
      ~title=opts.title->Option.getOr("ReScript API docs"),
      ~tagline=opts.tagline->Option.getOr(
        "Generated API documentation for ReScript packages.",
      ),
      ~base=normalizeBase(opts.base->Option.getOr("/")),
    )
    Node.log(
      `resdocs: index over ${Int.toString(count)} package` ++
      (count == 1 ? "" : "s") ++
      " written to " ++
      Node.relative(Node.cwd(), root) ++
      "/index.html",
    )
    0
  }
}

let main = async (argv: array<string>): int =>
  switch parseArgs(argv) {
  | Error(message) =>
    Node.warn(message)
    message == usage ? 0 : 2
  | Ok(opts) =>
    switch opts.command {
    | Build => await build(opts)
    | Index => writeIndex(opts)
    }
  }
