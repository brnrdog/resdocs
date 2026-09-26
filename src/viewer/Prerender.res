/* Build-time rendering of viewer pages, run by the CLI in Node. The
   CLI sets globalThis.__RESDOCS_BASE__ before importing this module,
   since Store reads the base when it loads. */

open Xote

/* The HTML of the app for one path, with the bundle already loaded. */
let render = (bundle: Bundle.bundle, ~pathname: string): string => {
  Router.initSSR(~basePath=Store.routerBase, ~pathname, ())
  Signal.set(Store.bundle, Some(bundle))
  SSR.renderToString(() => <App />)
}
