open Xote

@xote.component
let make = () =>
  <nav class="sidebar" ariaLabel="Modules">
    <ul class="nav-list">
      <View.For
        each={MaybeSignal.reactive(Store.topModules)}
        by={m => m.id}
        render={m => <SidebarEntry module_=m />}
      />
    </ul>
  </nav>
