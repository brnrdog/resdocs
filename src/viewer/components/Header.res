open Xote

/* The mark links to the package index when the site is part of one,
   and to the package home otherwise. The bundle arrives after the
   first render, so this is a tracked block rather than a one-shot
   read: an unconfigured hub would otherwise be latched in. */
let hubLink = () =>
  View.tracked(() =>
    switch Signal.get(Store.hubUrl) {
    | Some(url) =>
      <a class="hub" href=url>
        {Logo.make(~size=26)} <span> {View.text("resdocs")} </span>
      </a>
    | None =>
      <Router.Link to="/" class="hub">
        {Logo.make(~size=26)} <span> {View.text("resdocs")} </span>
      </Router.Link>
    }
  )

let packageIdentity = () =>
  <div class="package">
    <Router.Link to="/" class="package-name">
      {() => Signal.get(Store.packageName)}
    </Router.Link>
    <View.Show when_={MaybeSignal.computed(() => Signal.get(Store.packageVersion) != "")}>
      <span class="version"> {() => Signal.get(Store.packageVersion)} </span>
    </View.Show>
  </div>

let repoLink = () =>
  <View.Maybe
    value={MaybeSignal.reactive(Store.repoUrl)}
    render={url =>
      <a class="icon-button" href=url target="_blank" attrs=[("rel", "noreferrer")]>
        {View.text("Repository")}
      </a>}
  />

@xote.component
let make = () =>
  <header class="header">
    {hubLink()}
    {packageIdentity()}
    <SearchBox />
    <div class="header-actions">
      {repoLink()}
      <ThemeToggle />
    </div>
  </header>
