/* Minimal ReScript syntax highlighting: a single pass regex over the
   text that emits spans for comments, strings, attributes, keywords,
   labels, type variables, numbers and capitalized identifiers. */

open Xote

let keywords = [
  "let", "type", "rec", "and", "module", "open", "include", "external", "if", "else",
  "switch", "when", "try", "catch", "async", "await", "as", "of", "mutable", "private",
  "exception", "true", "false", "for", "in", "to", "downto", "while", "constraint",
]

let pattern =
  "(//[^\\n]*|/\\*[\\s\\S]*?\\*/)" ++ /* 1 comment */
  "|(\"(?:[^\"\\\\]|\\\\.)*\"|`(?:[^`\\\\]|\\\\.)*`)" ++ /* 2 string */
  "|(@@?[\\w.]+)" ++ /* 3 attribute */
  "|(~\\w+)" ++ /* 4 label */
  "|('\\w+)" ++ /* 5 type variable */
  "|(\\b\\d[\\d_]*(?:\\.\\d+)?\\b)" ++ /* 6 number */
  "|(\\b[A-Z]\\w*\\b)" ++ /* 7 capitalized */
  "|(\\b[a-z_]\\w*\\b)" /* 8 word, kept only if a keyword */

let span = (cls: string, text: string): View.node =>
  View.element("span", ~attrs=[View.attr("class", cls)], ~children=[View.text(text)], ())

let classOf = (result: RegExp.Result.t): option<string> => {
  let groups = RegExp.Result.matches(result)
  let has = i => groups->Array.get(i)->Option.flatMap(g => g)->Option.isSome
  if has(0) {
    Some("tok-comment")
  } else if has(1) {
    Some("tok-string")
  } else if has(2) {
    Some("tok-attr")
  } else if has(3) {
    Some("tok-label")
  } else if has(4) {
    Some("tok-tvar")
  } else if has(5) {
    Some("tok-number")
  } else if has(6) {
    Some("tok-type")
  } else if keywords->Array.includes(RegExp.Result.fullMatch(result)) {
    Some("tok-keyword")
  } else {
    None
  }
}

let highlight = (code: string): array<View.node> => {
  let re = RegExp.fromString(pattern, ~flags="g")
  let out = []
  let cursor = ref(0)
  let rec loop = () =>
    switch RegExp.exec(re, code) {
    | None => ()
    | Some(result) =>
      let text = RegExp.Result.fullMatch(result)
      let start = RegExp.Result.index(result)
      switch classOf(result) {
      | Some(cls) =>
        if start > cursor.contents {
          out->Array.push(View.text(code->String.slice(~start=cursor.contents, ~end=start)))
        }
        out->Array.push(span(cls, text))
        cursor := start + String.length(text)
      | None => ()
      }
      loop()
    }
  loop()
  if cursor.contents < String.length(code) {
    out->Array.push(View.text(code->String.slice(~start=cursor.contents)))
  }
  out
}
