/* Renders a docstring. The CLI parsed its Markdown into a Doc tree;
   here the tree is sanitized again and turned into xote nodes, with
   ReScript code blocks syntax highlighted. Nothing is evaluated.
   Falls back to the raw text when there is no tree. */

open Xote

let isRescript = (cls: string) =>
  cls->String.includes("language-rescript") || cls->String.includes("language-res")

let rec toNode = (node: Doc.node): View.node =>
  switch node {
  | Text({value}) => View.text(value)
  | Element({tag: "code", attrs, children}) =>
    let cls = attrs->Array.find(((name, _)) => name == "class")->Option.map(((_, v)) => v)
    let children = switch cls {
    | Some(cls) if isRescript(cls) => Highlight.highlight(Doc.textOf(children))
    | _ => children->Array.map(toNode)
    }
    element("code", attrs, children)
  | Element({tag, attrs, children}) => element(tag, attrs, children->Array.map(toNode))
  }

and element = (tag, attrs, children) =>
  View.element(
    tag,
    ~attrs=attrs->Array.map(((name, value)) => View.attr(name, value)),
    ~children,
    (),
  )

let plain = (text: string): View.node =>
  View.element("pre", ~attrs=[View.attr("class", "doc-plain")], ~children=[View.text(text)], ())

let render = (~tree: option<array<Doc.node>>, ~fallback: string): View.node =>
  switch tree {
  | Some(nodes) => View.fragment(Doc.sanitize(nodes)->Array.map(toNode))
  | None => fallback == "" ? View.empty() : plain(fallback)
  }
