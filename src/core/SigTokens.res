/* Tokenizer for signature strings.

   A `Word` is a candidate type path: an optional run of capitalized
   module segments followed by a lowercase identifier, such as `node`,
   `Xote.Signal.t` or `For.props`. Everything else, including labels
   and record fields (a name followed by a colon), type variables and
   punctuation, is `Other` text. The same split is used to resolve
   references at build time and to render links in the viewer, so the
   two can never disagree on what a token is. */

type token =
  | Word(string)
  | Other(string)

let keywords = ["let", "type", "rec", "and", "as", "module", "of", "mutable", "private"]

/* Not preceded by a word char, quote or dot, not followed by a word
   char, and not a label or field (no colon after optional spaces). */
let pattern = "(?<![\\w'.])((?:[A-Z]\\w*\\.)*[a-z_][\\w']*)(?![\\w'])(?!\\s*\\??\\s*:)"

let tokenize = (signature: string): array<token> => {
  let re = RegExp.fromString(pattern, ~flags="g")
  let out = []
  let cursor = ref(0)
  let rec loop = () =>
    switch RegExp.exec(re, signature) {
    | None => ()
    | Some(result) =>
      let word = RegExp.Result.fullMatch(result)
      let start = RegExp.Result.index(result)
      if start > cursor.contents {
        out->Array.push(Other(signature->String.slice(~start=cursor.contents, ~end=start)))
      }
      if keywords->Array.includes(word) {
        out->Array.push(Other(word))
      } else {
        out->Array.push(Word(word))
      }
      cursor := start + String.length(word)
      loop()
    }
  loop()
  if cursor.contents < String.length(signature) {
    out->Array.push(Other(signature->String.slice(~start=cursor.contents)))
  }
  out
}

let words = (signature: string): array<string> =>
  tokenize(signature)->Array.filterMap(token =>
    switch token {
    | Word(w) => Some(w)
    | Other(_) => None
    }
  )
