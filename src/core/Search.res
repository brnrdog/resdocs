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

let entry = (~kind, ~id, ~name, ~moduleId, ~anchor, ~signature, ~deprecated): entry => {
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

/* Ranking tiers, see docs/design.md section 4. */
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
  } else {
    0
  }
  if base == 0 {
    0
  } else if e.deprecated {
    base - 20
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

let search = (index: index, query: string, ~limit: int=50): array<entry> => {
  let q = query->String.trim->String.toLowerCase
  if q == "" {
    []
  } else {
    index
    ->Array.filterMap(e => {
      let s = score(e, q)
      s > 0 ? Some({entry: e, score: s}) : None
    })
    ->Array.toSorted(compareHits)
    ->Array.slice(~start=0, ~end=limit)
    ->Array.map(h => h.entry)
  }
}
