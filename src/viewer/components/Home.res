open Xote

let firstLine = (doc: string): string =>
  doc->String.split("\n")->Array.get(0)->Option.getOr("")

let moduleRow = (m: Bundle.module_): View.node =>
  <li class="home-module">
    <Router.Link to={"/module/" ++ m.id} class="home-link"> {View.text(m.id)} </Router.Link>
    <span class="home-summary"> {View.text(firstLine(m.doc))} </span>
  </li>

@xote.component
let make = () =>
  <main class="content" id="content">
    <article class="home">
      <h1> {() => Signal.get(Store.title)} </h1>
      <p class="home-intro">
        {() =>
          Signal.get(Store.bundle)->Option.mapOr("Loading documentation...", b =>
            `Package ${b.package}, ${Int.toString(Array.length(b.modules))} modules. Press / to search.`
          )}
      </p>
      <ul class="home-modules">
        <View.For each={MaybeSignal.reactive(Store.topModules)} by={m => m.id} render=moduleRow />
      </ul>
    </article>
  </main>
