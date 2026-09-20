/* Resolves the type names in every signature to item ids.

   Resolution order for a name seen inside module M: M itself, then
   each enclosing module, then the bundle-wide qualified index. A name
   that resolves to nothing stays plain text in the viewer. */

let index = (modules: array<Bundle.module_>): Set.t<string> => {
  let ids = Set.make()
  let rec walk = (m: Bundle.module_) => {
    m.types->Array.forEach(t => ids->Set.add(t.id))
    m.modules->Array.forEach(walk)
  }
  modules->Array.forEach(walk)
  ids
}

/* "Xote.View.For" -> ["Xote.View.For", "Xote.View", "Xote"] */
let scopesOf = (moduleId: string): array<string> => {
  let parts = moduleId->String.split(".")
  let out = []
  for n in Array.length(parts) downto 1 {
    out->Array.push(parts->Array.slice(~start=0, ~end=n)->Array.join("."))
  }
  out
}

let resolveName = (ids: Set.t<string>, scopes: array<string>, name: string): option<string> =>
  switch scopes->Array.findMap(scope => {
    let candidate = scope ++ "." ++ name
    ids->Set.has(candidate) ? Some(candidate) : None
  }) {
  | Some(id) => Some(id)
  | None => ids->Set.has(name) ? Some(name) : None
  }

let refsOf = (ids: Set.t<string>, scopes: array<string>, ~self: string, signature: string): array<
  Bundle.typeRef,
> => {
  let seen = Set.make()
  SigTokens.words(signature)->Array.filterMap(name =>
    if seen->Set.has(name) {
      None
    } else {
      seen->Set.add(name)
      switch resolveName(ids, scopes, name) {
      | Some(id) if id != self => Some({Bundle.name, id})
      | _ => None
      }
    }
  )
}

let rec applyToModule = (ids: Set.t<string>, m: Bundle.module_): Bundle.module_ => {
  let scopes = scopesOf(m.id)
  let withRefs = (item: Bundle.item): Bundle.item => {
    ...item,
    refs: refsOf(ids, scopes, ~self=item.id, item.signature),
  }
  {
    ...m,
    types: m.types->Array.map(withRefs),
    values: m.values->Array.map(withRefs),
    modules: m.modules->Array.map(applyToModule(ids, ...)),
  }
}

let apply = (modules: array<Bundle.module_>): array<Bundle.module_> => {
  let ids = index(modules)
  modules->Array.map(applyToModule(ids, ...))
}
