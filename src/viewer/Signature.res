/* A signature with its type names linked to their definitions. The
   tokenizer is shared with the CLI, so a name links exactly when the
   build resolved it. */

open Xote

let render = (item: Bundle.item): View.node => {
  let refs = Dict.fromArray(item.refs->Array.map(r => (r.name, r.id)))
  let nodes =
    SigTokens.tokenize(item.signature)->Array.flatMap(token =>
      switch token {
      | Word(word) =>
        switch refs->Dict.get(word)->Option.flatMap(Store.hrefOf) {
        | Some(href) => [
            Router.link(~to=href, ~attrs=[View.attr("class", "ref")], ~children=[View.text(word)], ()),
          ]
        | None => [View.text(word)]
        }
      | Other(text) => Highlight.highlight(text)
      }
    )
  View.element(
    "pre",
    ~attrs=[View.attr("class", "signature")],
    ~children=[View.element("code", ~children=nodes, ())],
    (),
  )
}

/* Field and constructor signatures: highlighted, not linked. */
let inline = (signature: string): View.node =>
  View.element("code", ~children=Highlight.highlight(signature), ())
