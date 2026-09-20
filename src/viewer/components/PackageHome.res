/* The package landing page: what this package is, how to install it,
   and every top level module. This is the page a reader arrives on
   from the package index. */

open Xote

let firstSentence = (doc: string): string => {
  let line = doc->String.split("\n")->Array.get(0)->Option.getOr("")
  switch line->String.indexOf(". ") {
  | -1 => line
  | i => line->String.slice(~start=0, ~end=i + 1)
  }
}

let counts = (m: Bundle.module_): string => {
  let rec walk = (m: Bundle.module_, acc) => {
    let acc = acc + Array.length(m.types) + Array.length(m.values)
    m.modules->Array.reduce(acc, (a, sub) => walk(sub, a))
  }
  let total = walk(m, 0)
  let subs = Array.length(m.modules)
  let items = `${Int.toString(total)} item` ++ (total == 1 ? "" : "s")
  subs == 0 ? items : `${items}, ${Int.toString(subs)} submodule` ++ (subs == 1 ? "" : "s")
}

let moduleCard = (m: Bundle.module_): View.node =>
  <li>
    <Router.Link to={"/module/" ++ m.id} class="module-card">
      <span class="module-card-name"> {View.text(m.id)} </span>
      <View.Show when_={MaybeSignal.static(firstSentence(m.doc) != "")}>
        <span class="module-card-summary"> {View.text(firstSentence(m.doc))} </span>
      </View.Show>
      <span class="module-card-counts"> {View.text(counts(m))} </span>
    </Router.Link>
  </li>

let metaItem = (label: string, href: option<string>): View.node =>
  switch href {
  | Some(url) =>
    <li>
      <a href=url target="_blank" attrs=[("rel", "noreferrer")]> {View.text(label)} </a>
    </li>
  | None => View.empty()
  }

let meta = () =>
  View.tracked(() => {
    let npm = Signal.get(Store.npmUrl)
    let repo = Signal.get(Store.repoUrl)
    <ul class="meta">
      {metaItem("npm", npm)}
      {metaItem("Repository", repo)}
      <View.Show when_={MaybeSignal.static(npm == None && repo == None)}>
        <li> <span> {View.text("No package links configured")} </span> </li>
      </View.Show>
    </ul>
  })

let install = () =>
  <View.Show when_={MaybeSignal.computed(() => Signal.get(Store.installLine) != None)}>
    <section class="install">
      <h2> {View.text("Install")} </h2>
      <pre><code> {() => Signal.get(Store.installLine)->Option.getOr("")} </code></pre>
    </section>
  </View.Show>

@xote.component
let make = () =>
  <main class="content" id="content">
    <article>
      <header class="package-hero">
        <h1>
          {Logo.make(~size=32)}
          <span> {() => Signal.get(Store.packageName)} </span>
          <View.Show when_={MaybeSignal.computed(() => Signal.get(Store.packageVersion) != "")}>
            <span class="version"> {() => Signal.get(Store.packageVersion)} </span>
          </View.Show>
        </h1>
        <View.Show when_={MaybeSignal.computed(() => Signal.get(Store.description) != "")}>
          <p class="tagline"> {() => Signal.get(Store.description)} </p>
        </View.Show>
        {meta()}
        {install()}
      </header>
      <section class="modules-section">
        <h2> {View.text("Modules")} </h2>
        <ul class="module-cards">
          <View.For each={MaybeSignal.reactive(Store.topModules)} by={m => m.id} render=moduleCard />
        </ul>
      </section>
    </article>
  </main>
