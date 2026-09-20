/* Browser bindings the viewer needs beyond what xote provides. Named
   Browser because Dom is the compiler-provided module. */

@get external key: Dom.event => string = "key"
@send external preventDefault: Dom.event => unit = "preventDefault"
@get external target: Dom.event => Dom.eventTarget = "target"
@get external targetValue: Dom.eventTarget => string = "value"
@get external targetTagName: Dom.eventTarget => string = "tagName"

@val @scope("document")
external getElementById: string => Nullable.t<Dom.element> = "getElementById"
@val @scope("document")
external querySelector: string => Nullable.t<Dom.element> = "querySelector"
@val external document: Dom.document = "document"
@set external setTitle: (Dom.document, string) => unit = "title"
@val @scope(("document", "documentElement"))
external setRootAttribute: (string, string) => unit = "setAttribute"
@val @scope("document")
external addDocumentListener: (string, Dom.event => unit) => unit = "addEventListener"
@val @scope("document")
external removeDocumentListener: (string, Dom.event => unit) => unit = "removeEventListener"

type scrollOptions = {block: string}
@send external scrollIntoView: (Dom.element, scrollOptions) => unit = "scrollIntoView"
@send external focus: Dom.element => unit = "focus"
@send external blur: Dom.element => unit = "blur"

@val @scope("localStorage") external getItem: string => Nullable.t<string> = "getItem"
@val @scope("localStorage") external setItem: (string, string) => unit = "setItem"

type mediaQuery = {matches: bool}
@val @scope("window") external matchMedia: string => mediaQuery = "matchMedia"
@val external requestAnimationFrame: (unit => unit) => unit = "requestAnimationFrame"

type response
@val external fetch: string => promise<response> = "fetch"
@send external text: response => promise<string> = "text"
@get external ok: response => bool = "ok"
@get external status: response => int = "status"

@val @scope("globalThis") external rawBase: Nullable.t<string> = "__RESDOCS_BASE__"

let readStorage = (k: string): option<string> =>
  try getItem(k)->Nullable.toOption catch {
  | _ => None
  }

let writeStorage = (k: string, v: string): unit =>
  try setItem(k, v) catch {
  | _ => ()
  }

let scrollToId = (id: string): unit =>
  switch getElementById(id)->Nullable.toOption {
  | Some(el) => el->scrollIntoView({block: "start"})
  | None => ()
  }
