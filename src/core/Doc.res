/* Rendered docstrings as data. The CLI parses a docstring's Markdown
   into this tree and the viewer turns it into nodes, so a docstring
   never becomes code: nothing in a bundle is evaluated.

   `sanitize` keeps only the tags and attributes plain Markdown with
   GitHub extensions produces, and only safe URLs. The CLI applies it
   before writing a bundle and the viewer again before rendering, so
   a hand-edited bundle cannot inject script either. */

@tag("t")
type rec node =
  | @as("e") Element({tag: string, attrs: array<(string, string)>, children: array<node>})
  | @as("x") Text({value: string})

let allowedTags = [
  "a",
  "blockquote",
  "br",
  "code",
  "del",
  "em",
  "h1",
  "h2",
  "h3",
  "h4",
  "h5",
  "h6",
  "hr",
  "img",
  "input",
  "li",
  "ol",
  "p",
  "pre",
  "section",
  "strong",
  "sup",
  "table",
  "tbody",
  "td",
  "th",
  "thead",
  "tr",
  "ul",
]

/* Relative links, fragments and web or mail URLs. Anything with
   another scheme (javascript:, data:, vbscript:, ...) is dropped.
   Control characters and whitespace are stripped first, the way a
   browser does before it reads the scheme. */
let isSafeUrl = (url: string): bool => {
  let compact =
    url
    ->String.replaceRegExp(/[\u0000- \u007f-\u009f]/g, "")
    ->String.toLowerCase
  switch compact->String.indexOf(":") {
  | -1 => true
  | colon =>
    let slash = compact->String.indexOf("/")
    let query = compact->String.indexOf("?")
    let hash = compact->String.indexOf("#")
    let before = i => i != -1 && i < colon
    before(slash) || before(query) || before(hash)
      ? true
      : ["http:", "https:", "mailto:"]->Array.some(s => compact->String.startsWith(s))
  }
}

let isSafeAttr = (tag: string, name: string, value: string): bool =>
  switch (tag, name) {
  | ("a", "href") | ("img", "src") => isSafeUrl(value)
  | ("a", "title" | "aria-label") | ("img", "alt") | ("img", "title") => true
  | ("code", "class") =>
    value->String.split(" ")->Array.every(c => c->String.startsWith("language-"))
  | ("ol", "start") => value->String.match(/^\d+$/)->Option.isSome
  | ("td" | "th", "align") => ["left", "center", "right"]->Array.includes(value)
  | ("input", "type") => value == "checkbox"
  | ("input", "checked" | "disabled") => true
  /* GitHub footnotes link to ids under their own prefix. */
  | (_, "id") => value->String.startsWith("user-content-")
  | _ => false
  }

/* Disallowed elements are unwrapped: their text survives, the tag
   does not. */
let rec sanitize = (nodes: array<node>): array<node> =>
  nodes->Array.flatMap(node =>
    switch node {
    | Text(_) => [node]
    | Element({tag, attrs, children}) =>
      let children = sanitize(children)
      allowedTags->Array.includes(tag)
        ? [
            Element({
              tag,
              attrs: attrs->Array.filter(((name, value)) => isSafeAttr(tag, name, value)),
              children,
            }),
          ]
        : children
    }
  )

let rec textOf = (nodes: array<node>): string =>
  nodes
  ->Array.map(node =>
    switch node {
    | Text({value}) => value
    | Element({children}) => textOf(children)
    }
  )
  ->Array.join("")
