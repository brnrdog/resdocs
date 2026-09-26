/* Search index and ranking. Pure: no signals, no DOM, so it is
   testable in Node and reusable in the viewer, where a Computed over
   the query signal calls `search` on every keystroke. */

type kind =
  | @as("module") Module
  | @as("type") Type
  | @as("value") Value

type entry = {
  id: string,
  name: string,
  lower: string,
  initials: string,
  idLower: string,
  sigLower: string,
  kind: kind,
  moduleId: string,
  anchor: string,
  signature: string,
  /* First sentence of the docstring, shown under a result. */
  summary: string,
  docLower: string,
  deprecated: bool,
}

type index = array<entry>

/* "eachWithKey" -> "ewk", "to_string" -> "ts" */
let initials = (name: string): string => {
  let out = ref("")
  let afterSep = ref(true)
  name
  ->String.split("")
  ->Array.forEach(ch => {
    if ch == "_" {
      afterSep := true
    } else if afterSep.contents || (ch->String.toUpperCase == ch && ch->String.toLowerCase != ch) {
      out := out.contents ++ ch->String.toLowerCase
      afterSep := false
    }
  })
  out.contents
}

/* Markdown punctuation that reads as noise in a one-line summary. */
let plain = (text: string): string =>
  text->String.replaceRegExp(/[`*_]/g, "")->String.trim

let entry = (~kind, ~id, ~name, ~moduleId, ~anchor, ~signature, ~doc="", ~deprecated): entry => {
  id,
  name,
  lower: name->String.toLowerCase,
  initials: initials(name),
  idLower: id->String.toLowerCase,
  sigLower: signature->String.toLowerCase,
  kind,
  moduleId,
  anchor,
  signature,
  summary: plain(Bundle.firstSentence(doc)),
  docLower: doc->String.toLowerCase,
  deprecated,
}

let build = (bundle: Bundle.bundle): index => {
  let out = []
  let rec walk = (~topId: string, m: Bundle.module_) => {
    out->Array.push(
      entry(
        ~kind=Module,
        ~id=m.id,
        ~name=m.name,
        ~moduleId=topId,
        ~anchor=m.anchor,
        ~signature="",
        ~doc=m.doc,
        ~deprecated=m.deprecated->Option.isSome,
      ),
    )
    let pushItem = (kind, item: Bundle.item) =>
      out->Array.push(
        entry(
          ~kind,
          ~id=item.id,
          ~name=item.name,
          ~moduleId=topId,
          ~anchor=item.anchor,
          ~signature=item.signature,
          ~doc=item.doc,
          ~deprecated=item.deprecated->Option.isSome,
        ),
      )
    m.types->Array.forEach(pushItem(Type, ...))
    m.values->Array.forEach(pushItem(Value, ...))
    m.modules->Array.forEach(walk(~topId, ...))
  }
  bundle.modules->Array.forEach(m => walk(~topId=m.id, m))
  out
}

/* A query is text plus an optional kind filter written as a prefix:
   `type:`, `value:` or `module:` (or `t:`, `v:`, `m:`). */
type query = {text: string, kind: option<kind>}

let parseQuery = (raw: string): query => {
  let q = raw->String.trim->String.toLowerCase
  let prefixes = [
    ("type:", Type),
    ("t:", Type),
    ("value:", Value),
    ("v:", Value),
    ("module:", Module),
    ("m:", Module),
  ]
  switch prefixes->Array.find(((p, _)) => q->String.startsWith(p)) {
  | Some((p, kind)) => {text: q->String.slice(~start=String.length(p))->String.trim, kind: Some(kind)}
  | None => {text: q, kind: None}
  }
}

/* Ranking tiers, see docs/design.md section 4. A query of several
   words that matches no tier as a whole still matches when every word
   appears in the path, the signature or the docstring. */
let score = (e: entry, q: string): int => {
  let base = if e.lower == q {
    100
  } else if e.lower->String.startsWith(q) {
    80
  } else if e.initials->String.startsWith(q) {
    60
  } else if e.lower->String.includes(q) {
    40
  } else if e.idLower->String.includes(q) {
    30
  } else if e.sigLower->String.includes(q) {
    10
  } else if e.docLower->String.includes(q) {
    5
  } else {
    let words = q->String.split(" ")->Array.filter(w => w != "")
    Array.length(words) > 1 &&
      words->Array.every(w =>
        e.idLower->String.includes(w) || e.sigLower->String.includes(w) || e.docLower->String.includes(w)
      )
      ? 3
      : 0
  }
  if base == 0 {
    0
  } else if e.deprecated {
    /* Below every live match of the same tier, never out of the list. */
    Math.Int.max(1, base - 20)
  } else {
    base
  }
}
type hit = {entry: entry, score: int}

let compareHits = (a: hit, b: hit): Ordering.t =>
  if a.score != b.score {
    Int.compare(b.score, a.score)
  } else if String.length(a.entry.name) != String.length(b.entry.name) {
    Int.compare(String.length(a.entry.name), String.length(b.entry.name))
  } else {
    String.compare(a.entry.id, b.entry.id)
  }

/* Every match, best first. A bare kind filter (`type:`) lists every
   entry of that kind. */
let rank = (index: index, raw: string): array<entry> => {
  let {text, kind} = parseQuery(raw)
  let ofKind = (e: entry) =>
    switch kind {
    | Some(k) => e.kind == k
    | None => true
    }
  if text == "" && kind == None {
    []
  } else {
    index
    ->Array.filterMap(e =>
      if !ofKind(e) {
        None
      } else if text == "" {
        Some({entry: e, score: e.deprecated ? 1 : 2})
      } else {
        let s = score(e, text)
        s > 0 ? Some({entry: e, score: s}) : None
      }
    )
    ->Array.toSorted(compareHits)
    ->Array.map(h => h.entry)
  }
}

let search = (index: index, query: string, ~limit: int=50): array<entry> =>
  rank(index, query)->Array.slice(~start=0, ~end=limit)

/* The name split into runs that do and do not match the query, for
   highlighting: the matched substring, or the initials that matched. */
type segment = {text: string, matched: bool}

let highlight = (name: string, raw: string): array<segment> => {
  let q = parseQuery(raw).text
  let lower = name->String.toLowerCase
  let piece = (start, end_, matched) => {text: name->String.slice(~start, ~end=end_), matched}
  let keep = segments => segments->Array.filter(s => s.text != "")
  if q == "" {
    [{text: name, matched: false}]
  } else {
    switch lower->String.indexOf(q) {
    | -1 if initials(name)->String.startsWith(q) =>
      /* Mark the capitals and post-underscore letters that spelled q. */
      let marks = []
      let left = ref(String.length(q))
      let afterSep = ref(true)
      name
      ->String.split("")
      ->Array.forEach(ch => {
        let isInitial =
          ch != "_" && (afterSep.contents || (ch->String.toUpperCase == ch && ch->String.toLowerCase != ch))
        afterSep := ch == "_"
        if isInitial && left.contents > 0 {
          left := left.contents - 1
          marks->Array.push({text: ch, matched: true})
        } else {
          marks->Array.push({text: ch, matched: false})
        }
      })
      /* Merge neighbours with the same state. */
      marks->Array.reduce([], (acc: array<segment>, s) =>
        switch acc->Array.at(-1) {
        | Some(last) if last.matched == s.matched =>
          acc->Array.slice(~start=0, ~end=-1)->Array.concat([{...last, text: last.text ++ s.text}])
        | _ => acc->Array.concat([s])
        }
      )
    | -1 => [{text: name, matched: false}]
    | i =>
      let end_ = i + String.length(q)
      keep([piece(0, i, false), piece(i, end_, true), piece(end_, String.length(name), false)])
    }
  }
}
