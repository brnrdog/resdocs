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

let normalizeBase = (base: string): string => {
  let b = base->String.startsWith("/") ? base : "/" ++ base
  b->String.endsWith("/") ? b : b ++ "/"
}

/* ---------------------------------------------------------------- docs */

let mapAsync = async (items: array<'a>, f: 'a => promise<'b>): array<'b> => {
  let out = []
  for i in 0 to Array.length(items) - 1 {
    out->Array.push(await f(items->Array.getUnsafe(i)))
  }
  out
}

let compileDoc = async (doc: string): option<string> =>
  doc == "" ? None : (await Node.compileDoc(doc))->Nullable.toOption

let compileField = async (f: Bundle.field): Bundle.field => {
  ...f,
  docCode: await compileDoc(f.doc),
}

let compileConstructor = async (c: Bundle.constructor): Bundle.constructor => {
  ...c,
  docCode: await compileDoc(c.doc),
  fields: await mapAsync(c.fields, compileField),
}

let compileItem = async (item: Bundle.item): Bundle.item => {
  ...item,
  docCode: await compileDoc(item.doc),
  detail: switch item.detail {
  | Abstract => Abstract
  | Record({fields}) => Record({fields: await mapAsync(fields, compileField)})
  | Variant({constructors}) =>
    Variant({constructors: await mapAsync(constructors, compileConstructor)})
  },
}

let rec compileModule = async (m: Bundle.module_): Bundle.module_ => {
  ...m,
  docCode: await compileDoc(m.doc),
  types: await mapAsync(m.types, compileItem),
  values: await mapAsync(m.values, compileItem),
  modules: await mapAsync(m.modules, compileModule),
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

let writeSite = (~out: string, ~base: string, ~title: string): result<unit, string> => {
  let viewer = Node.join([Node.packageRoot, "dist", "viewer"])
  if !Node.existsSync(Node.join([viewer, "index.html"])) {
    Error("viewer not built at " ++ viewer ++ ", run `npm run build` in resdocs")
  } else {
    Node.copyDir(viewer, out)
    Node.writeFileSync(Node.join([out, "logo.svg"]), Hub.logoFile)
    let index = Node.join([out, "index.html"])
    let html =
      Node.readFileSync(index)
      ->String.replaceAll("/__RESDOCS_BASE__/", base)
      ->String.replaceAll("__RESDOCS_TITLE__", title)
    Node.writeFileSync(index, html)
    /* GitHub Pages serves 404.html for unknown paths: deep links load. */
    Node.writeFileSync(Node.join([out, "404.html"]), html)
    Ok()
  }
}

let build = async (opts: options): int => {
  let projectDir = Node.resolve(Node.cwd(), opts.project)
  let opts = withConfigFile(opts, projectDir)
  switch Project.load(projectDir) {
  | Error(e) => fail(e)
  | Ok(project) =>
    switch await Tools.locate(projectDir) {
    | Error(e) => fail(e)
    | Ok(tools) =>
      let built = Tools.isBuilt(projectDir)
        ? Ok()
        : {
            Node.log("resdocs: compiling " ++ project.name)
            Tools.build(tools)
          }
      switch built {
      | Error(e) => fail(e)
      | Ok() =>
        let files =
          Project.sourceFiles(project)->Array.filter(file => {
            let name = Project.moduleNameOf(file)
            !(opts.exclude->Array.some(p => Normalize.matchesPattern(p, name)))
          })
        let docs = files->Array.filterMap(file =>
          switch Tools.doc(tools, file) {
          | Ok(json) => Some(Docgen.parse(json))
          | Error(e) =>
            Node.warn("resdocs: skipping " ++ Node.relative(projectDir, file) ++ ": " ++ e)
            None
          }
        )
        let namespace = docs->Array.get(0)->Option.flatMap(Normalize.namespaceOf)
        let modules = Refs.apply(docs->Array.map(doc => Normalize.ofDoc(doc)))
        let modules = await mapAsync(modules, compileModule)
        modules->Array.forEach(m => {
          let (missing, total) = undocumented(m)
          if missing > 0 {
            Node.warn(
              `resdocs: ${m.id}: ${Int.toString(missing)} of ${Int.toString(total)} items have no docstring`,
            )
          }
        })
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
          switch writeSite(~out, ~base=normalizeBase(opts.base->Option.getOr("/")), ~title) {
          | Ok() =>
            Node.log("resdocs: site written to " ++ Node.relative(Node.cwd(), out))
            0
          | Error(e) => fail(e)
          }
        }
      }
    }
  }
}

let writeIndex = (opts: options): int => {
  let root = Node.resolve(Node.cwd(), opts.out)
  if !Node.existsSync(root) {
    fail("no such directory: " ++ opts.out)
  } else {
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
