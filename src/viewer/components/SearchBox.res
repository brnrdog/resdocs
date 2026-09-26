open Xote

let inputId = "search-input"
let listId = "search-results"

let kindName = (kind: Search.kind) =>
  switch kind {
  | Module => "module"
  | Type => "type"
  | Value => "value"
  }

let firstLine = (s: string) => s->String.split("\n")->Array.get(0)->Option.getOr("")

/* Option ids for aria-activedescendant; module paths are valid ids. */
let optionId = (id: string) => "result-" ++ id

let focusInput = () =>
  switch Browser.getElementById(inputId)->Nullable.toOption {
  | Some(el) => Browser.focus(el)
  | None => ()
  }

let blurInput = () =>
  switch Browser.getElementById(inputId)->Nullable.toOption {
  | Some(el) => Browser.blur(el)
  | None => ()
  }

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
    blurInput()
  | "Escape" =>
    /* First Escape clears the query, the second leaves the box. */
    if Signal.peek(Store.query) != "" {
      Store.setQuery("")
    } else {
      blurInput()
    }
  | _ => ()
  }

/* The name with the part the query matched marked. */
let highlighted = (name: string): View.node =>
  View.tracked(() =>
    View.fragment(
      Search.highlight(name, Signal.get(Store.query))->Array.map(seg =>
        seg.matched ? <mark> {View.text(seg.text)} </mark> : View.text(seg.text)
      ),
    )
  )

let resultRow = (entry: Search.entry): View.node => {
  let index = () => Signal.get(Store.listed)->Array.findIndex(e => e.id == entry.id)
  <li
    role="option"
    class="result"
    id={optionId(entry.id)}
    attrs=[
      View.computedAttr("aria-selected", () =>
        Signal.get(Store.selectedId) == Some(entry.id) ? "true" : "false"
      ),
    ]
    onMouseMove={_ =>
      if Signal.peek(Store.selectedId) != Some(entry.id) {
        Store.select(index())
      }}
    onMouseDown={evt => {
      Browser.preventDefault(evt)
      Store.navigateTo(entry)
      blurInput()
    }}>
    <span class="result-name"> {highlighted(entry.name)} </span>
    <span class={"badge badge-" ++ kindName(entry.kind)}> {View.text(kindName(entry.kind))} </span>
    <span class="result-path"> {View.text(entry.id)} </span>
    {entry.signature != ""
      ? <span class="result-sig"> {View.text(firstLine(entry.signature))} </span>
      : View.empty()}
    {entry.summary != ""
      ? <span class="result-summary"> {View.text(entry.summary)} </span>
      : View.empty()}
  </li>
}

let panelHeading = () =>
  View.tracked(() =>
    if Signal.get(Store.showingRecent) {
      <div class="results-heading">
        <span> {View.text("Recently viewed")} </span>
        <button
          type_="button"
          class="link-button"
          onMouseDown={evt => {
            Browser.preventDefault(evt)
            Store.clearRecent()
          }}>
          {View.text("Clear")}
        </button>
      </div>
    } else {
      let total = Signal.get(Store.resultTotal)
      let shown = Array.length(Signal.get(Store.results))
      <div class="results-heading" role="status">
        <span>
          {View.text(
            switch total {
            | 0 => "No matches"
            | 1 => "1 result"
            | n if n > shown => `${Int.toString(shown)} of ${Int.toString(n)} results`
            | n => `${Int.toString(n)} results`
            },
          )}
        </span>
      </div>
    }
  )

let emptyHint = () =>
  <View.Show
    when_={MaybeSignal.computed(() =>
      !Signal.get(Store.showingRecent) && Signal.get(Store.resultTotal) == 0
    )}>
    <p class="results-empty">
      {View.text("Nothing matches. Try part of a name, initials such as ")}
      <code> {View.text("ewk")} </code>
      {View.text(", or a few words from the docs.")}
    </p>
  </View.Show>

let footer = () =>
  <div class="results-footer" ariaHidden=true>
    <span> <kbd> {View.text("↑")} </kbd> <kbd> {View.text("↓")} </kbd> {View.text(" move")} </span>
    <span> <kbd> {View.text("↵")} </kbd> {View.text(" open")} </span>
    <span> <kbd> {View.text("esc")} </kbd> {View.text(" close")} </span>
    <span class="results-filters">
      <code> {View.text("type:")} </code>
      {View.text(" ")}
      <code> {View.text("value:")} </code>
      {View.text(" ")}
      <code> {View.text("module:")} </code>
      {View.text(" filter")}
    </span>
  </div>

/* "/" or Ctrl/Cmd+K focuses the search box from anywhere outside a
   text field. */
let globalShortcut = (evt: Dom.event) => {
  let key = Browser.key(evt)
  let tag = try evt->Browser.target->Browser.targetTagName catch {
  | _ => ""
  }
  let inField = tag == "INPUT" || tag == "TEXTAREA"
  if (key == "/" && !inField) || (key == "k" && (Browser.ctrlKey(evt) || Browser.metaKey(evt))) {
    Browser.preventDefault(evt)
    focusInput()
  }
}

@xote.component
let make = () => {
  Effect.run(() =>
    if Browser.isBrowser {
      Browser.addDocumentListener("keydown", globalShortcut)
      Some(() => Browser.removeDocumentListener("keydown", globalShortcut))
    } else {
      None
    }
  )
  /* Keep the keyboard selection visible inside the scrolling list. */
  Effect.run(() => {
    switch Signal.get(Store.selectedId) {
    | Some(_) if Browser.isBrowser =>
      Browser.requestAnimationFrame(() =>
        switch Browser.querySelector(".result[aria-selected=\"true\"]")->Nullable.toOption {
        | Some(el) => el->Browser.scrollIntoView({block: "nearest"})
        | None => ()
        }
      )
    | _ => ()
    }
    None
  })
  <div class="search" role="search">
    <input
      id=inputId
      type_="search"
      class="search-input"
      placeholder="Search the API"
      autoComplete="off"
      spellcheck=false
      role="combobox"
      value={Store.query}
      onInput
      onKeyDown
      onFocus={_ => Store.setSearchFocused(true)}
      onBlur={_ => Store.setSearchFocused(false)}
      attrs=[
        View.attr("aria-controls", listId),
        View.attr("aria-autocomplete", "list"),
        View.attr("aria-keyshortcuts", "/ Control+K Meta+K"),
        View.computedAttr("aria-expanded", () => Signal.get(Store.panelOpen) ? "true" : "false"),
        View.optionalComputedAttr("aria-activedescendant", () =>
          Signal.get(Store.panelOpen) ? Signal.get(Store.selectedId)->Option.map(optionId) : None
        ),
      ]
    />
    <kbd class="search-key" ariaHidden=true> {View.text("/")} </kbd>
    <View.Show when_={MaybeSignal.reactive(Store.panelOpen)}>
      <div class="results">
        {panelHeading()}
        <ul id=listId class="results-list" role="listbox" ariaLabel="Search results">
          <View.For each={MaybeSignal.reactive(Store.listed)} by={e => e.id} render=resultRow />
        </ul>
        {emptyHint()}
        {footer()}
      </div>
    </View.Show>
  </div>
}
