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

let load = async () => {
  let response = await Browser.fetch(Store.base ++ "resdocs.json")
  if !Browser.ok(response) {
    Console.error("resdocs: could not load resdocs.json, status " ++ Int.toString(Browser.status(response)))
  } else {
    let text = await Browser.text(response)
    Signal.set(Store.bundle, Some(Bundle.parse(text)))
  }
}

View.mountById(<App />, "app")
load()->ignore
