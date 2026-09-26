open Xote

@xote.component
let make = () =>
  <div class="app">
    <Header />
    <div class="body">
      <Sidebar />
      {switch (Signal.get(Store.loadError), Signal.get(Store.page)) {
      | (Some(message), _) =>
        <main class="content" id="content">
          <div class="load-error" role="alert">
            <p> <strong> {View.text("This documentation could not be loaded.")} </strong> </p>
            <p> {View.text(message)} </p>
          </div>
        </main>
      | (None, HomePage) => <PackageHome />
      | (None, ModulePage | NotFoundPage) => <ModulePage />
      }}
    </div>
  </div>
