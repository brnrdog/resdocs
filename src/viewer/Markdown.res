/* Renders a docstring. The CLI precompiled it to an MDX function
   body; here it runs against xote's JSX runtime and `Mdx.render`
   turns the result into nodes, with `code` overridden for syntax
   highlighting. Falls back to the raw text when there is no code. */

open Xote

@module("./mdxRuntime.mjs") external runDoc: string => Mdx.document = "runDoc"

type codeProps = {className?: string, children?: Mdx.children}

let isRescript = (cls: string) =>
  cls->String.includes("language-rescript") || cls->String.includes("language-res")

let code = (props: codeProps): View.node => {
  let text = props.children->Option.mapOr("", Mdx.childrenToText)
  let children = switch props.className {
  | Some(cls) if isRescript(cls) => Highlight.highlight(text)
  | _ => [View.text(text)]
  }
  View.element(
    "code",
    ~attrs=props.className->Option.mapOr([], cls => [View.attr("class", cls)]),
    ~children,
    (),
  )
}

let components = Mdx.components([("code", Mdx.component(code))])

let plain = (text: string): View.node =>
  View.element("pre", ~attrs=[View.attr("class", "doc-plain")], ~children=[View.text(text)], ())

let render = (~code: option<string>, ~fallback: string): View.node =>
  switch code {
  | Some(body) =>
    try Mdx.render(runDoc(body), ~components, ()) catch {
    | _ => plain(fallback)
    }
  | None => fallback == "" ? View.empty() : plain(fallback)
  }
