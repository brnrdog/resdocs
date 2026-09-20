open Xote

@xote.component
let make = () =>
  <div class="app">
    <header class="header">
      <Router.Link to="/" class="brand"> {() => Signal.get(Store.title)} </Router.Link>
      <SearchBox />
      <ThemeToggle />
    </header>
    <div class="body">
      <Sidebar />
      {switch Signal.get(Store.page) {
      | HomePage => <Home />
      | ModulePage | NotFoundPage => <ModulePage />
      }}
    </div>
  </div>
