open Zekr

let entry = (~slug, ~name, ~version="", ~description="", ~modules=1, ~items=1): Hub.entry => {
  slug,
  name,
  version,
  description,
  modules,
  items,
}

let suite = Suite.make(
  "Hub",
  [
    Test.make("html special characters are escaped", () => {
      Assert.equal(
        Hub.escape(`<a href="x">&'`),
        "&lt;a href=&quot;x&quot;&gt;&amp;'",
      )
    }),
    Test.make("a card links to the package directory", () => {
      let html = Hub.card(entry(~slug="rescript-signals", ~name="rescript-signals", ~version="3.1.4"))
      Assert.combineResults([
        Assert.contains(html, `href="rescript-signals/"`),
        Assert.contains(html, `<span class="card-name">rescript-signals</span>`),
        Assert.contains(html, `<span class="card-version">3.1.4</span>`),
      ])
    }),
    Test.make("a scoped name is escaped and linked by slug", () => {
      let html = Hub.card(entry(~slug="rescript-relay", ~name="@rescript-relay/core"))
      Assert.combineResults([
        Assert.contains(html, `href="rescript-relay/"`),
        Assert.contains(html, "@rescript-relay/core"),
      ])
    }),
    Test.make("missing version and description are omitted", () => {
      let html = Hub.card(entry(~slug="xote", ~name="xote"))
      Assert.combineResults([
        Assert.isFalse(html->String.includes("card-version")),
        Assert.isFalse(html->String.includes("card-summary")),
      ])
    }),
    Test.make("counts are pluralized", () => {
      let one = Hub.card(entry(~slug="a", ~name="a", ~modules=1, ~items=1))
      let many = Hub.card(entry(~slug="b", ~name="b", ~modules=7, ~items=105))
      Assert.combineResults([
        Assert.contains(one, "1 module, 1 item<"),
        Assert.contains(many, "7 modules, 105 items<"),
      ])
    }),
    Test.make("items are counted through nested modules", () => {
      let modules = [Normalize.ofDoc(Docgen.parse(NodeFs.readFixture("probe.json")))]
      /* Probe: 4 at the top, 4 in Inner, 1 in S, 0 in Alias */
      Assert.combineResults([
        Assert.equal(Hub.countItems(modules), 9),
        Assert.equal(Hub.countItems([]), 0),
      ])
    }),
    Test.make("an entry takes its name from the bundle, falling back to the slug", () => {
      let base: Bundle.bundle = {
        version: 1,
        package: "",
        packageVersion: "1.0.0",
        description: "d",
        namespace: None,
        title: "t",
        hub: None,
        repo: None,
        generatedAt: "",
        modules: [],
      }
      let named = Hub.entryOf(~slug="slug", {...base, package: "pkg"})
      let unnamed = Hub.entryOf(~slug="slug", base)
      Assert.combineResults([
        Assert.equal(named.name, "pkg"),
        Assert.equal(unnamed.name, "slug"),
        Assert.equal(named.version, "1.0.0"),
        Assert.equal(named.description, "d"),
      ])
    }),
    Test.make("the rendered page carries the title, tagline and cards", () => {
      let html = Hub.render(
        ~title="ReScript API docs",
        ~tagline="Generated API documentation.",
        ~base="/resdocs/",
        [entry(~slug="xote", ~name="xote", ~version="7.2.0-beta.1")],
      )
      Assert.combineResults([
        Assert.contains(html, "<title>ReScript API docs</title>"),
        Assert.contains(html, "Generated API documentation."),
        Assert.contains(html, `href="/resdocs/logo.svg"`),
        Assert.contains(html, `href="xote/"`),
        Assert.isFalse(html->String.includes("__HUB_")),
      ])
    }),
    Test.make("an empty directory still renders a page", () => {
      let html = Hub.render(~title="t", ~tagline="g", ~base="/", [])
      Assert.combineResults([
        Assert.contains(html, "No packages yet"),
        Assert.isFalse(html->String.includes("__HUB_PACKAGES__")),
      ])
    }),
  ],
)

Runner.runSuites([suite])
