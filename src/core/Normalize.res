/* Turns one `rescript-tools doc` document into a bundle module.

   Ids are display paths computed from nesting ("Xote.View.For.make")
   because the tool's own ids are wrong for nested module aliases.
   Reference resolution needs the whole bundle and happens later in
   `Refs`. */

let joinDocs = (docstrings: array<string>): string =>
  docstrings->Array.map(String.trim)->Array.filter(s => s != "")->Array.join("\n\n")

/* "View-Xote" is the file module View in namespace Xote. */
let splitModuleName = (name: string): (string, option<string>) =>
  switch name->String.split("-") {
  | [moduleName, namespace] => (moduleName, Some(namespace))
  | _ => (name, None)
  }

let anchorOf = (prefix: string, relPath: array<string>): string =>
  prefix ++ "-" ++ relPath->Array.join("-")

let source = (s: Docgen.source): Bundle.source => {file: s.filepath, line: s.line}

let field = (f: Docgen.field): Bundle.field => {
  name: f.name,
  signature: f.signature,
  optional: f.optional,
  doc: joinDocs(f.docstrings),
  docCode: None,
  deprecated: f.deprecated,
}

let constructor = (c: Docgen.constructor): Bundle.constructor => {
  name: c.name,
  signature: c.signature,
  doc: joinDocs(c.docstrings),
  docCode: None,
  deprecated: c.deprecated,
  fields: switch c.payload {
  | Some(InlineRecord({fields})) => fields->Array.map(field)
  | None => []
  },
}

let typeDetail = (detail: option<Docgen.detail>): Bundle.typeDetail =>
  switch detail {
  | Some(Record({items})) => Record({fields: items->Array.map(field)})
  | Some(Variant({items})) => Variant({constructors: items->Array.map(constructor)})
  | Some(Signature(_)) | None => Abstract
  }

let item = (
  ~parentId: string,
  ~relPath: array<string>,
  ~kind: Bundle.kind,
  ~name: string,
  ~docstrings: array<string>,
  ~signature: string,
  ~deprecated: option<string>,
  ~source as src: Docgen.source,
  ~detail: option<Docgen.detail>,
): Bundle.item => {
  let path = relPath->Array.concat([name])
  {
    id: parentId ++ "." ++ name,
    anchor: anchorOf(
      switch kind {
      | Type => "type"
      | Value => "value"
      },
      path,
    ),
    kind,
    name,
    signature,
    doc: joinDocs(docstrings),
    docCode: None,
    deprecated,
    source: source(src),
    detail: switch kind {
    | Type => typeDetail(detail)
    | Value => Abstract
    },
    refs: [],
  }
}

let rec module_ = (
  ~id: string,
  ~relPath: array<string>,
  ~name: string,
  ~kind: Bundle.moduleKind,
  ~docstrings: array<string>,
  ~deprecated: option<string>,
  ~source as src: Docgen.source,
  ~items: array<Docgen.item>,
): Bundle.module_ => {
  let types = []
  let values = []
  let modules = []
  items->Array.forEach(entry =>
    switch entry {
    | Value({name, docstrings, signature, ?deprecated, source, ?detail}) =>
      values->Array.push(
        item(
          ~parentId=id,
          ~relPath,
          ~kind=Value,
          ~name,
          ~docstrings,
          ~signature,
          ~deprecated,
          ~source,
          ~detail,
        ),
      )
    | Type({name, docstrings, signature, ?deprecated, source, ?detail}) =>
      types->Array.push(
        item(
          ~parentId=id,
          ~relPath,
          ~kind=Type,
          ~name,
          ~docstrings,
          ~signature,
          ~deprecated,
          ~source,
          ~detail,
        ),
      )
    | Module({name, docstrings, ?deprecated, source, items}) =>
      modules->Array.push(
        module_(
          ~id=id ++ "." ++ name,
          ~relPath=relPath->Array.concat([name]),
          ~name,
          ~kind=Module,
          ~docstrings,
          ~deprecated,
          ~source,
          ~items,
        ),
      )
    | ModuleType({name, docstrings, ?deprecated, source, items}) =>
      modules->Array.push(
        module_(
          ~id=id ++ "." ++ name,
          ~relPath=relPath->Array.concat([name]),
          ~name,
          ~kind=ModuleType,
          ~docstrings,
          ~deprecated,
          ~source,
          ~items,
        ),
      )
    | ModuleAlias({name, docstrings, source, items}) =>
      modules->Array.push(
        module_(
          ~id=id ++ "." ++ name,
          ~relPath=relPath->Array.concat([name]),
          ~name,
          ~kind=Alias,
          ~docstrings,
          ~deprecated=None,
          ~source,
          ~items,
        ),
      )
    }
  )
  {
    id,
    name,
    kind,
    anchor: relPath->Array.length == 0 ? "top" : anchorOf("module", relPath),
    doc: joinDocs(docstrings),
    docCode: None,
    deprecated,
    source: source(src),
    types,
    values,
    modules,
  }
}

/* The file module of one document. The namespace comes from the
   tool's module name; the caller may pass an override. */
let ofDoc = (~namespace: option<string>=?, doc: Docgen.doc): Bundle.module_ => {
  let (name, inferred) = splitModuleName(doc.name)
  let namespace = switch namespace {
  | Some(_) => namespace
  | None => inferred
  }
  let id = switch namespace {
  | Some(ns) => ns ++ "." ++ name
  | None => name
  }
  module_(
    ~id,
    ~relPath=[],
    ~name,
    ~kind=Module,
    ~docstrings=doc.docstrings,
    ~deprecated=doc.deprecated->Nullable.toOption,
    ~source=doc.source,
    ~items=doc.items,
  )
}

/* Namespace reported by the tool for a document, if any. */
let namespaceOf = (doc: Docgen.doc): option<string> => Pair.second(splitModuleName(doc.name))

/* Simple glob: `*` matches any run of characters. Used for module
   exclusion patterns such as "Runtime*". */
let matchesPattern = (pattern: string, name: string): bool => {
  let parts = pattern->String.split("*")
  switch parts {
  | [exact] => exact == name
  | _ =>
    let first = parts->Array.getUnsafe(0)
    let last = parts->Array.getUnsafe(Array.length(parts) - 1)
    if !(name->String.startsWith(first)) || !(name->String.endsWith(last)) {
      false
    } else {
      let middle = parts->Array.slice(~start=1, ~end=Array.length(parts) - 1)
      let rest = ref(name->String.slice(~start=String.length(first), ~end=String.length(name) - String.length(last)))
      middle->Array.every(part => {
        switch rest.contents->String.indexOfOpt(part) {
        | None => false
        | Some(i) =>
          rest := rest.contents->String.slice(~start=i + String.length(part))
          true
        }
      })
    }
  }
}
