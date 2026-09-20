open Xote

let inputId = "search-input"

let kindName = (kind: Search.kind) =>
  switch kind {
  | Module => "module"
  | Type => "type"
  | Value => "value"
  }

let firstLine = (s: string) => s->String.split("\n")->Array.get(0)->Option.getOr("")

let onInput = (evt: Dom.event) => Store.setQuery(evt->Browser.target->Browser.targetValue)

let onKeyDown = (evt: Dom.event) =>
  switch Browser.key(evt) {
  | "ArrowDown" =>
    Browser.preventDefault(evt)
    Store.moveSelection(1)
  | "ArrowUp" =>
    Browser.preventDefault(evt)
    Store.moveSelection(-1)
  | "Enter" =>
    Browser.preventDefault(evt)
    Store.submit()
  | "Escape" =>
    Store.setQuery("")
    switch Browser.getElementById(inputId)->Nullable.toOption {
    | Some(el) => Browser.blur(el)
    | None => ()
    }
  | _ => ()
  }

let resultRow = (entry: Search.entry): View.node =>
  <li
    role="option"
    class="result"
    attrs=[
      View.computedAttr("aria-selected", () =>
        Signal.get(Store.selectedId) == Some(entry.id) ? "true" : "false"
      ),
    ]
    onMouseDown={evt => {
      Browser.preventDefault(evt)
      Store.navigateTo(entry)
    }}>
    <span class={"badge badge-" ++ kindName(entry.kind)}> {View.text(kindName(entry.kind))} </span>
    <span class="result-name"> {View.text(entry.name)} </span>
    <span class="result-path"> {View.text(entry.id)} </span>
    <span class="result-sig"> {View.text(firstLine(entry.signature))} </span>
  </li>

/* "/" focuses the search box from anywhere outside a text field. */
let globalShortcut = (evt: Dom.event) =>
  if Browser.key(evt) == "/" {
    let tag = try evt->Browser.target->Browser.targetTagName catch {
    | _ => ""
    }
    if tag != "INPUT" && tag != "TEXTAREA" {
      Browser.preventDefault(evt)
      switch Browser.getElementById(inputId)->Nullable.toOption {
      | Some(el) => Browser.focus(el)
      | None => ()
      }
    }
  }

@xote.component
let make = () => {
  Effect.run(() => {
    Browser.addDocumentListener("keydown", globalShortcut)
    Some(() => Browser.removeDocumentListener("keydown", globalShortcut))
  })
  /* Keep the keyboard selection visible inside the scrolling list. */
  Effect.run(() => {
    switch Signal.get(Store.selectedId) {
    | Some(_) =>
      Browser.requestAnimationFrame(() =>
        switch Browser.querySelector(".result[aria-selected=\"true\"]")->Nullable.toOption {
        | Some(el) => el->Browser.scrollIntoView({block: "nearest"})
        | None => ()
        }
      )
    | None => ()
    }
    None
  })
  <div class="search" role="search">
    <input
      id=inputId
      type_="search"
      class="search-input"
      placeholder="Search modules, types, values"
      autoComplete="off"
      role="combobox"
      value={Store.query}
      onInput
      onKeyDown
      attrs=[
        View.attr("aria-controls", "search-results"),
        View.attr("aria-autocomplete", "list"),
        View.computedAttr("aria-expanded", () => Signal.get(Store.query) != "" ? "true" : "false"),
      ]
    />
    <View.Show when_={MaybeSignal.computed(() => Signal.get(Store.query) != "")}>
      <ul id="search-results" class="results" role="listbox">
        <View.For each={MaybeSignal.reactive(Store.results)} by={e => e.id} render=resultRow />
        <View.Show when_={MaybeSignal.computed(() => Array.length(Signal.get(Store.results)) == 0)}>
          <li class="result-empty"> {View.text("No matches")} </li>
        </View.Show>
      </ul>
    </View.Show>
  </div>
}
