open Zekr

let bundle = (): Bundle.bundle => {
  version: 1,
  package: "xote",
  packageVersion: "",
  description: "",
  namespace: Some("Xote"),
  title: "xote",
  hub: None,
  repo: None,
  generatedAt: "",
  modules: [
    Normalize.ofDoc(Docgen.parse(NodeFs.readFixture("xote-View.json"))),
    Normalize.ofDoc(Docgen.parse(NodeFs.readFixture("xote-Router.json"))),
    Normalize.ofDoc(Docgen.parse(NodeFs.readFixture("xote-Route.json"))),
    Normalize.ofDoc(Docgen.parse(NodeFs.readFixture("probe.json"))),
  ],
}

let index = () => Search.build(bundle())
let names = (q, ~limit=?) => Search.search(index(), q, ~limit?)->Array.map(e => e.id)
let first = q => names(q)->Array.get(0)

let suite = Suite.make(
  "Search",
  [
    Test.make("index covers modules, types and values", () => {
      let ix = index()
      Assert.combineResults([
        Assert.isTrue(ix->Array.some(e => e.id == "Xote.View" && e.kind == Search.Module)),
        Assert.isTrue(ix->Array.some(e => e.id == "Xote.View.For" && e.kind == Search.Module)),
        Assert.isTrue(ix->Array.some(e => e.id == "Xote.View.node" && e.kind == Search.Type)),
        Assert.isTrue(
          ix->Array.some(e => e.id == "Xote.View.For.make" && e.moduleId == "Xote.View" && e.anchor == "value-For-make"),
        ),
      ])
    }),
    Test.make("initials", () => {
      Assert.combineResults([
        Assert.equal(Search.initials("eachWithKey"), "ewk"),
        Assert.equal(Search.initials("to_string"), "ts"),
        Assert.equal(Search.initials("View"), "v"),
      ])
    }),
    Test.make("exact name wins over prefix", () => {
      Assert.equal(first("each"), Some("Xote.View.each"))
    }),
    Test.make("prefix wins over substring", () => {
      let ids = names("attr")
      /* `attr` and the `Attr` module are both exact matches */
      Assert.combineResults([
        Assert.equal(ids->Array.slice(~start=0, ~end=2)->Array.toSorted(String.compare), ["Xote.View.Attr", "Xote.View.attr"]),
        Assert.isTrue(ids->Array.indexOf("Xote.View.attrValue") < ids->Array.indexOf("Xote.View.signalAttr")),
      ])
    }),
    Test.make("camelCase initials", () => {
      Assert.equal(first("ewk"), Some("Xote.View.eachWithKey"))
    }),
    Test.make("query is case insensitive and trimmed", () => {
      Assert.equal(first("  EachWithKey "), Some("Xote.View.eachWithKey"))
    }),
    Test.make("qualified id matches when the name does not", () => {
      Assert.arrayContains(names("view.for"), "Xote.View.For.make")
    }),
    Test.make("signature matches rank last", () => {
      let ids = names("Xote.Signal.t")
      Assert.combineResults([
        Assert.isTrue(ids->Array.length > 0),
        Assert.arrayContains(ids, "Xote.View.signalAttr"),
      ])
    }),
    Test.make("deprecated items rank below live ones with the same match", () => {
      let ids = names("match")
      let live = ids->Array.indexOf("Xote.Route.match")
      let deprecated = ids->Array.indexOf("Xote.Route.matchPath")
      Assert.combineResults([
        Assert.equal(first("match"), Some("Xote.Route.match")),
        Assert.isTrue(live < deprecated),
        Assert.isTrue(index()->Array.some(e => e.id == "Xote.Route.matchPath" && e.deprecated)),
      ])
    }),
    Test.make("shorter names break ties", () => {
      let ids = names("signal")
      Assert.isTrue(ids->Array.indexOf("Xote.View.signalInt") < ids->Array.indexOf("Xote.View.signalFloat"))
    }),
    Test.make("results are capped", () => {
      Assert.combineResults([
        Assert.equal(names("e", ~limit=5)->Array.length, 5),
        Assert.isTrue(names("e")->Array.length <= 50),
      ])
    }),
    Test.make("empty query returns nothing", () => {
      Assert.combineResults([Assert.equal(names(""), []), Assert.equal(names("   "), [])])
    }),
    Test.make("no match returns nothing", () => {
      Assert.equal(names("zzzzzz"), [])
    }),
    Test.make("kind prefixes filter results", () => {
      let kinds = q => Search.search(index(), q)->Array.map(e => e.kind)
      Assert.combineResults([
        Assert.equal(Search.parseQuery("  Type: Node "), {text: "node", kind: Some(Search.Type)}),
        Assert.equal(Search.parseQuery("v:make"), {text: "make", kind: Some(Search.Value)}),
        Assert.equal(Search.parseQuery("make"), {text: "make", kind: None}),
        Assert.isTrue(kinds("type: node")->Array.every(k => k == Search.Type)),
        Assert.isTrue(Array.length(kinds("type: node")) > 0),
        Assert.isTrue(kinds("module:")->Array.every(k => k == Search.Module)),
        Assert.isTrue(Array.length(kinds("module:")) > 3),
        Assert.equal(first("value: run"), Some("Probe.run")),
      ])
    }),
    Test.make("docstrings match below names, with a one-line summary", () => {
      let run = index()->Array.find(e => e.id == "Probe.run")
      Assert.combineResults([
        Assert.equal(first("a variant"), Some("Probe.shape")),
        Assert.equal(run->Option.map(e => e.summary), Some("Doc for run.")),
        /* A name match outranks a docstring match. */
        Assert.equal(first("run"), Some("Probe.run")),
      ])
    }),
    Test.make("several words match across path, signature and docs", () =>
      Assert.equal(first("probe inner type"), Some("Probe.Inner.t"))
    ),
    Test.make("highlight marks the matched substring or initials", () => {
      let marks = (name, q) =>
        Search.highlight(name, q)->Array.map(s => s.matched ? "[" ++ s.text ++ "]" : s.text)->Array.join("")
      Assert.combineResults([
        Assert.equal(marks("eachWithKey", "with"), "each[With]Key"),
        Assert.equal(marks("eachWithKey", "ewk"), "[e]ach[W]ith[K]ey"),
        Assert.equal(marks("to_string", "ts"), "[t]o_[s]tring"),
        Assert.equal(marks("make", "value: ma"), "[ma]ke"),
        Assert.equal(marks("make", "zz"), "make"),
        Assert.equal(marks("make", ""), "make"),
      ])
    }),
  ],
)

Runner.runSuites([suite])
