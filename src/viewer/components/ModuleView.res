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

let fieldRow = (f: Bundle.field): View.node =>
  <tr>
    <td> <code class="field-name"> {View.text(f.name ++ (f.optional ? "?" : ""))} </code> </td>
    <td> {Signature.inline(f.signature)} </td>
    <td> {doc(~code=f.docCode, ~fallback=f.doc)} {deprecated(f.deprecated)} </td>
  </tr>

let fieldsTable = (fields: array<Bundle.field>): View.node =>
  <table class="fields">
    <thead> <tr> <th> {View.text("Field")} </th> <th> {View.text("Type")} </th> <th> {View.text("Doc")} </th> </tr> </thead>
    <tbody>
      <View.For each={MaybeSignal.static(fields)} by={f => f.name} render=fieldRow />
    </tbody>
  </table>

let constructorRow = (c: Bundle.constructor): View.node =>
  <li class="constructor">
    {Signature.inline(c.signature)}
    {doc(~code=c.docCode, ~fallback=c.doc)}
    {deprecated(c.deprecated)}
    {Array.length(c.fields) > 0 ? fieldsTable(c.fields) : View.empty()}
  </li>

let detail = (item: Bundle.item): View.node =>
  switch item.detail {
  | Abstract => View.empty()
  | Record({fields}) => fieldsTable(fields)
  | Variant({constructors}) =>
    <ul class="constructors">
      <View.For each={MaybeSignal.static(constructors)} by={c => c.name} render=constructorRow />
    </ul>
  }

let itemCard = (item: Bundle.item): View.node =>
  <section class="item" id={item.anchor}>
    <h3 class="item-title">
      {anchorLink(item.anchor)}
      {badge(kindName(item.kind))}
      <code> {View.text(item.name)} </code>
      {sourceLink(item.source)}
    </h3>
    {Signature.render(item)}
    {deprecated(item.deprecated)}
    {detail(item)}
    {doc(~code=item.docCode, ~fallback=item.doc)}
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
