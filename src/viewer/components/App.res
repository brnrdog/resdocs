open Xote

@xote.component
let make = () =>
  <div class="app">
    <Header />
    <div class="body">
      <Sidebar />
      {switch Signal.get(Store.page) {
      | HomePage => <PackageHome />
      | ModulePage | NotFoundPage => <ModulePage />
      }}
    </div>
  </div>
