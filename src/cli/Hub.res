/* The package index: one page listing every bundle in a directory,
   so a site can host the docs of many ReScript packages.

   Each subdirectory of the hub root that has a `resdocs.json` is a
   package. The page is plain HTML with the ReScript palette inlined,
   no JavaScript, because it only has to link onward. */

let escape = (text: string): string =>
  text
  ->String.replaceAll("&", "&amp;")
  ->String.replaceAll("<", "&lt;")
  ->String.replaceAll(">", "&gt;")
  ->String.replaceAll("\"", "&quot;")

let logo = `<svg width="26" height="26" viewBox="0 0 32 32" fill="none" aria-hidden="true"><rect width="32" height="32" rx="7" fill="currentColor"/><path d="M16 9.6v14.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/><path d="M16 9.6C13.9 8.2 11.4 7.6 8.4 7.9c-.8.1-1.4.8-1.4 1.6v11.8c0 .9.8 1.7 1.7 1.6 2.7-.2 5 .3 6.9 1.5M16 9.6c2.1-1.4 4.6-2 7.6-1.7.8.1 1.4.8 1.4 1.6v11.8c0 .9-.8 1.7-1.7 1.6-2.7-.2-5 .3-6.9 1.5" stroke="#fff" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/></svg>`

let logoFile = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="32" height="32"><rect width="32" height="32" rx="7" fill="#e6484f"/><path d="M16 9.6v14.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/><path d="M16 9.6C13.9 8.2 11.4 7.6 8.4 7.9c-.8.1-1.4.8-1.4 1.6v11.8c0 .9.8 1.7 1.7 1.6 2.7-.2 5 .3 6.9 1.5M16 9.6c2.1-1.4 4.6-2 7.6-1.7.8.1 1.4.8 1.4 1.6v11.8c0 .9-.8 1.7-1.7 1.6-2.7-.2-5 .3-6.9 1.5" fill="none" stroke="#fff" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/></svg>`

type entry = {
  slug: string,
  name: string,
  version: string,
  description: string,
  modules: int,
  items: int,
}

let countItems = (modules: array<Bundle.module_>): int => {
  let rec walk = (m: Bundle.module_, acc) => {
    let acc = acc + Array.length(m.types) + Array.length(m.values)
    m.modules->Array.reduce(acc, (a, sub) => walk(sub, a))
  }
  modules->Array.reduce(0, (a, m) => walk(m, a))
}

let entryOf = (~slug: string, bundle: Bundle.bundle): entry => {
  slug,
  name: bundle.package == "" ? slug : bundle.package,
  version: bundle.packageVersion,
  description: bundle.description,
  modules: Array.length(bundle.modules),
  items: countItems(bundle.modules),
}

/* Every immediate subdirectory holding a resdocs.json. */
let scan = (root: string): array<entry> =>
  Node.readdirSync(root)
  ->Array.toSorted(String.compare)
  ->Array.filterMap(slug => {
    let dir = Node.join([root, slug])
    let bundleFile = Node.join([dir, "resdocs.json"])
    if Node.statSync(dir)->Node.isDirectory && Node.existsSync(bundleFile) {
      Some(entryOf(~slug, Bundle.parse(Node.readFileSync(bundleFile))))
    } else {
      None
    }
  })

let plural = (count: int, word: string): string =>
  `${Int.toString(count)} ${word}` ++ (count == 1 ? "" : "s")

let card = (entry: entry): string => {
  let version =
    entry.version == "" ? "" : `<span class="card-version">${escape(entry.version)}</span>`
  let summary =
    entry.description == ""
      ? ""
      : `<span class="card-summary">${escape(entry.description)}</span>`
  let counts = `${plural(entry.modules, "module")}, ${plural(entry.items, "item")}`
  `<li><a class="card" href="${escape(entry.slug)}/"><span class="card-name">${escape(
      entry.name,
    )}</span>${version}${summary}<span class="card-counts">${counts}</span></a></li>`
}

let render = (~title: string, ~tagline: string, ~base: string, entries: array<entry>): string => {
  let template = Node.readFileSync(
    Node.join([Node.packageRoot, "src", "cli", "templates", "hub.html"]),
  )
  let packages = switch entries {
  | [] => `<li><a class="card" href="."><span class="card-summary">No packages yet</span></a></li>`
  | entries => entries->Array.map(card)->Array.join("")
  }
  template
  ->String.replaceAll("__HUB_TITLE__", escape(title))
  ->String.replaceAll("__HUB_TAGLINE__", escape(tagline))
  ->String.replaceAll("__HUB_BASE__", escape(base))
  ->String.replaceAll("__HUB_LOGO__", logo)
  ->String.replaceAll("__HUB_PACKAGES__", packages)
}

let write = (~root: string, ~title: string, ~tagline: string, ~base: string): int => {
  let entries = scan(root)
  Node.writeFileSync(Node.join([root, "logo.svg"]), logoFile)
  Node.writeFileSync(
    Node.join([root, "index.html"]),
    render(~title, ~tagline, ~base, entries),
  )
  Array.length(entries)
}
