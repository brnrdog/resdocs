/** Module-level docstring with **markdown** and a list:
- one
- two
*/

/** A record with an optional field. */
type rec conf = {name: string, count?: int, next: option<conf>}

/** A variant.
```rescript
let x = A
```
*/
type shape = A | B(int) | C({w: float, h: float})

/** Doc for `run`. */
let run = (~label: string, ~retries=3, items: array<conf>, f: conf => shape): result<shape, string> =>
{
  ignore(f)
  Error(label ++ Int.toString(retries) ++ Int.toString(Array.length(items)))
}

@deprecated("Use run") let old = (x: int) => x

/** Nested module docs */
module Inner = {
  /** inner type */
  type t = string
  let make = (s: string): t => s
  let sig_ = Xote.Signal.make(0)
  let node = Xote.View.text("x")
}

module type S = {
  let v: int
}

module Alias = Inner
