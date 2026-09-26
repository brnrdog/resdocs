/* Viewer entry: router, bundle fetch, document effects, mount. */

open Xote

Router.init(~basePath=Store.routerBase, ())

/* Theme on the root element and in storage. */
Effect.run(() => {
  let name = Store.themeName(Signal.get(Store.theme))
  Browser.setRootAttribute("data-theme", name)
  Browser.writeStorage("resdocs-theme", name)
  None
})

/* Document title follows the page. */
Effect.run(() => {
  let title = Signal.get(Store.title)
  Browser.setTitle(
    Browser.document,
    switch Signal.get(Store.currentModuleId) {
    | Some(id) => id ++ " - " ++ title
    | None => title
    },
  )
  None
})

/* Deep links: once the module is rendered, scroll to the hash. The
   router does this on push; this covers cold loads and the bundle
   arriving after the first render. */
Effect.run(() => {
  switch Signal.get(Store.currentModule) {
  | Some(_) =>
    let hash = Signal.peek(Router.location()).hash
    if hash != "" {
      Browser.requestAnimationFrame(() =>
        Browser.scrollToId(Store.decodeURIComponent(hash->String.slice(~start=1)))
      )
    }
  | None => ()
  }
  None
})

/* The CLI pre-renders every page into #app, so the page reads before
   any script runs. The live app replaces that markup once the bundle
   is in, keeping the reader's scroll position. Without pre-rendered
   markup (the dev server) the app mounts at once and shows its own
   loading state. */
let prerendered = switch Browser.getElementById("app")->Nullable.toOption {
| Some(el) => Browser.hasChildNodes(el)
| None => false
}

let mount = () => View.mountById(<App />, "app")

let takeOver = () =>
  switch Browser.getElementById("app")->Nullable.toOption {
  | Some(el) =>
    let y = Browser.scrollY
    Browser.setInnerHTML(el, "")
    mount()
    Browser.scrollTo(0.0, y)
  | None => ()
  }

/* A pre-rendered page is still correct documentation, so it stays up
   when the bundle cannot be loaded; only its search and navigation
   are missing. */
let fail = (message: string) => {
  Console.error("resdocs: " ++ message)
  if !prerendered {
    Signal.set(Store.loadError, Some(message))
  }
}

let load = async () =>
  switch await Browser.fetch(Store.base ++ "resdocs.json") {
  | exception _ => fail("Could not reach resdocs.json. Check the connection and reload.")
  | response if !Browser.ok(response) =>
    fail(`Could not load resdocs.json (HTTP ${Int.toString(Browser.status(response))}).`)
  | response =>
    switch Bundle.decode(await Browser.text(response)) {
    | Ok(bundle) =>
      Signal.set(Store.bundle, Some(bundle))
      if prerendered {
        takeOver()
      }
    | Error(message) => fail(message)
    }
  }

if !prerendered {
  mount()
}
load()->ignore
