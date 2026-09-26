open Xote

let recentLink = (entry: Search.entry): View.node =>
  <li>
    <Router.Link
      to={Store.pathOf({moduleId: entry.moduleId, anchor: entry.anchor})}
      class="nav-recent"
      attrs=[View.attr("title", entry.id)]>
      <span class="nav-recent-name"> {View.text(entry.name)} </span>
      <span class="nav-recent-path"> {View.text(entry.id)} </span>
    </Router.Link>
  </li>

/* The last few pages and items the reader opened, kept per site in
   local storage. Empty on the pre-rendered page and on a first visit. */
let recent = () => {
  let entries = Computed.make(() => Signal.get(Store.recentEntries)->Array.slice(~start=0, ~end=5))
  <View.Show when_={MaybeSignal.computed(() => Array.length(Signal.get(entries)) > 0)}>
    <section class="sidebar-section" ariaLabel="Recently viewed">
      <div class="sidebar-heading">
        <span> {View.text("Recent")} </span>
        <button type_="button" class="link-button" onClick={_ => Store.clearRecent()}>
          {View.text("Clear")}
        </button>
      </div>
      <ul class="nav-list">
        <View.For each={MaybeSignal.reactive(entries)} by={e => e.id} render=recentLink />
      </ul>
    </section>
  </View.Show>
}

@xote.component
let make = () =>
  <nav class="sidebar" ariaLabel="Modules">
    {recent()}
    <div class="sidebar-heading"> {View.text("Modules")} </div>
    <ul class="nav-list">
      <View.For
        each={MaybeSignal.reactive(Store.topModules)}
        by={m => m.id}
        render={m => <SidebarEntry module_=m />}
      />
    </ul>
  </nav>
