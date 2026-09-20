/* Static rendering of one module page: header, types, values and
   nested modules. Nothing here is reactive; the page as a whole is
   re-rendered when the current module changes. */

open Xote

let kindName = (kind: Bundle.kind) =>
  switch kind {
  | Type => "type"
  | Value => "value"
  }

let moduleKindName = (kind: Bundle.moduleKind) =>
  switch kind {
  | Module => "module"
  | ModuleType => "module type"
  | Alias => "alias"
  }

let badge = (text: string): View.node =>
  <span class={"badge badge-" ++ text->String.replace(" ", "-")}> {View.text(text)} </span>

let sourceLink = (source: Bundle.source): View.node =>
  switch Signal.peek(Store.bundle)->Option.flatMap(b => Bundle.sourceUrl(b, source)) {
  | Some(url) =>
    <a class="source" href=url target="_blank" attrs=[("rel", "noreferrer")]>
      {View.text("Source")}
    </a>
  | None => View.empty()
  }

let anchorLink = (anchor: string): View.node =>
  <a class="anchor" href={"#" ++ anchor} ariaLabel="Link to this section"> {View.text("#")} </a>

let deprecated = (message: option<string>): View.node =>
  switch message {
  | Some(msg) =>
    <p class="deprecated"> <strong> {View.text("Deprecated. ")} </strong> {View.text(msg)} </p>
  | None => View.empty()
  }

let doc = (~code: option<string>, ~fallback: string): View.node =>
  fallback == "" ? View.empty() : <div class="doc"> {Markdown.render(~code, ~fallback)} </div>

let documented = (field: Bundle.field) => field.doc != "" || field.deprecated->Option.isSome

/* The Doc column only earns its width when something fills it. */
let fieldRow = (~withDoc: bool, f: Bundle.field): View.node =>
  <tr>
    <td> <code class="field-name"> {View.text(f.name ++ (f.optional ? "?" : ""))} </code> </td>
    <td> {Signature.inline(f.signature)} </td>
    {withDoc
      ? <td> {doc(~code=f.docCode, ~fallback=f.doc)} {deprecated(f.deprecated)} </td>
      : View.empty()}
  </tr>

let fieldsTable = (fields: array<Bundle.field>): View.node => {
  let withDoc = fields->Array.some(documented)
  <table class="fields">
    <thead>
      <tr>
        <th> {View.text("Field")} </th>
        <th> {View.text("Type")} </th>
        {withDoc ? <th> {View.text("Doc")} </th> : View.empty()}
      </tr>
    </thead>
    <tbody>
      <View.For
        each={MaybeSignal.static(fields)}
        by={f => f.name}
        render={f => fieldRow(~withDoc, f)}
      />
    </tbody>
  </table>
}

let constructorRow = (c: Bundle.constructor): View.node =>
  <li class="constructor">
    <div class="constructor-head"> {Signature.inline(c.signature)} </div>
    {deprecated(c.deprecated)}
    {doc(~code=c.docCode, ~fallback=c.doc)}
    {Array.length(c.fields) > 0 ? fieldsTable(c.fields) : View.empty()}
  </li>

/* A variant's signature already lists its constructors, so the
   expanded list is only worth its space when a constructor carries
   its own documentation or an inline record payload. */
let constructorsWorthListing = (constructors: array<Bundle.constructor>) =>
  constructors->Array.some(c =>
    c.doc != "" || c.deprecated->Option.isSome || Array.length(c.fields) > 0
  )

let detail = (item: Bundle.item): View.node =>
  switch item.detail {
  | Abstract => View.empty()
  | Record({fields}) => Array.length(fields) == 0 ? View.empty() : fieldsTable(fields)
  | Variant({constructors}) =>
    constructorsWorthListing(constructors)
      ? <ul class="constructors">
          <View.For each={MaybeSignal.static(constructors)} by={c => c.name} render=constructorRow />
        </ul>
      : View.empty()
  }

let itemCard = (item: Bundle.item): View.node =>
  <section class="item" id={item.anchor}>
    <h3 class="item-title">
      {anchorLink(item.anchor)}
      <code> {View.text(item.name)} </code>
      {sourceLink(item.source)}
    </h3>
    {Signature.render(item)}
    {deprecated(item.deprecated)}
    {doc(~code=item.docCode, ~fallback=item.doc)}
    {detail(item)}
  </section>

let group = (~title: string, ~anchor: string, items: array<Bundle.item>): View.node =>
  Array.length(items) == 0
    ? View.empty()
    : <section class="group" id=anchor>
        <h2> {anchorLink(anchor)} {View.text(title)} </h2>
        <View.For each={MaybeSignal.static(items)} by={i => i.id} render=itemCard />
      </section>

let rec sections = (m: Bundle.module_): View.node => {
  let prefix = m.anchor == "top" ? "" : m.anchor ++ "-"
  <>
    {group(~title="Types", ~anchor=prefix ++ "types", m.types)}
    {group(~title="Values", ~anchor=prefix ++ "values", m.values)}
    <View.For each={MaybeSignal.static(m.modules)} by={s => s.id} render=submodule />
  </>
}
and submodule = (m: Bundle.module_): View.node =>
  <section class="submodule" id={m.anchor}>
    <h2 class="submodule-title">
      {anchorLink(m.anchor)}
      {badge(moduleKindName(m.kind))}
      <code> {View.text(m.id)} </code>
      {sourceLink(m.source)}
    </h2>
    {deprecated(m.deprecated)}
    {doc(~code=m.docCode, ~fallback=m.doc)}
    {sections(m)}
  </section>

let render = (m: Bundle.module_): View.node =>
  <article class="module">
    <header class="module-header">
      <h1> {badge("module")} <code> {View.text(m.id)} </code> {sourceLink(m.source)} </h1>
      {deprecated(m.deprecated)}
      {doc(~code=m.docCode, ~fallback=m.doc)}
    </header>
    {sections(m)}
  </article>
