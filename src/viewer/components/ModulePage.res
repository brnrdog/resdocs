open Xote

let fallback = () =>
  View.tracked(() =>
    Signal.get(Store.loaded)
      ? <p class="notice"> {View.text("No such module.")} </p>
      : <p class="notice"> {View.text("Loading documentation...")} </p>
  )

@xote.component
let make = () =>
  <main class="content" id="content">
    <View.Maybe
      value={MaybeSignal.reactive(Store.currentModule)}
      render={m => ModuleView.render(m)}
      fallback={fallback()}
    />
  </main>
