open Xote

let rec tree = (m: Bundle.module_, ~top: string): View.node =>
  <li>
    <Router.Link to={"/module/" ++ top ++ "#" ++ m.anchor} class="nav-sub"> {View.text(m.name)} </Router.Link>
    {Array.length(m.modules) > 0
      ? <ul class="nav-sub-list"> {m.modules->Array.map(sub => tree(sub, ~top))} </ul>
      : View.empty()}
  </li>

@xote.component
let make = (~module_: Bundle.module_) => {
  let active = () =>
    switch Signal.get(Store.currentModuleId) {
    | Some(id) => id == module_.id || id->String.startsWith(module_.id ++ ".")
    | None => false
    }
  <li class="nav-item">
    <Router.Link
      to={"/module/" ++ module_.id}
      class="nav-link"
      attrs=[View.optionalComputedAttr("aria-current", () => active() ? Some("page") : None)]>
      {View.text(module_.id)}
    </Router.Link>
    <View.Show when_={MaybeSignal.computed(() => active() && Array.length(module_.modules) > 0)}>
      <ul class="nav-sub-list"> {module_.modules->Array.map(sub => tree(sub, ~top=module_.id))} </ul>
    </View.Show>
  </li>
}
