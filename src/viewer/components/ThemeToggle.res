open Xote

@xote.component
let make = () =>
  <button
    type_="button"
    class="theme-toggle"
    onClick={_ => Store.toggleTheme()}
    attrs=[
      View.computedAttr("aria-label", () =>
        switch Signal.get(Store.theme) {
        | Dark => "Switch to light theme"
        | Light => "Switch to dark theme"
        }
      ),
    ]>
    {() =>
      switch Signal.get(Store.theme) {
      | Dark => "Light"
      | Light => "Dark"
      }}
  </button>
