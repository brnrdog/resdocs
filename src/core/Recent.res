/* The reader's recently viewed pages and items: ids, most recent
   first, without duplicates. Pure, so the viewer only adds storage. */

let limit = 20

let add = (list: array<string>, id: string): array<string> =>
  [id]->Array.concat(list->Array.filter(x => x != id))->Array.slice(~start=0, ~end=limit)

let encode = (list: array<string>): string => JSON.stringifyAny(list)->Option.getOr("[]")

/* Anything unreadable is an empty history, never an error. */
let decode = (text: option<string>): array<string> =>
  switch text->Option.map(t =>
    try JSON.parseOrThrow(t) catch {
    | _ => JSON.Null
    }
  ) {
  | Some(Array(items)) =>
    items->Array.filterMap(JSON.Decode.string)->Array.slice(~start=0, ~end=limit)
  | _ => []
  }
