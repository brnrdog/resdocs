open Zekr

let modules = () =>
  Refs.apply([
    Normalize.ofDoc(Docgen.parse(NodeFs.readFixture("xote-View.json"))),
    Normalize.ofDoc(Docgen.parse(NodeFs.readFixture("probe.json"))),
  ])

let itemIn = (modules: array<Bundle.module_>, moduleId, name) =>
  modules
  ->Array.flatMap(m => Bundle.allModules({
    version: 1, package: "", namespace: None, title: "", repo: None, generatedAt: "", modules: [m],
  }))
  ->Array.find(m => m.id == moduleId)
  ->Option.flatMap(m =>
    m.values->Array.concat(m.types)->Array.find(i => i.name == name)
  )
  ->Option.getOrThrow

let refIds = (item: Bundle.item) => item.refs->Array.map(r => r.id)

let suite = Suite.make(
  "Refs",
  [
    Test.make("local names resolve inside the module", () => {
      let element = itemIn(modules(), "Xote.View", "element")
      Assert.combineResults([
        Assert.equal(refIds(element), ["Xote.View.attrValue", "Xote.View.node"]),
        Assert.equal(element.refs->Array.map(r => r.name), ["attrValue", "node"]),
      ])
    }),
    Test.make("names resolve through enclosing modules", () => {
      let make = itemIn(modules(), "Xote.View.For", "make")
      Assert.equal(refIds(make), ["Xote.View.For.props", "Xote.View.node"])
    }),
    Test.make("qualified names resolve across modules", () => {
      let props = itemIn(modules(), "Xote.View.For", "props")
      Assert.arrayContains(refIds(props), "Xote.View.node")
    }),
    Test.make("unresolvable names are dropped", () => {
      let element = itemIn(modules(), "Xote.View", "element")
      Assert.isFalse(element.refs->Array.some(r => r.name == "string"))
    }),
    Test.make("a type does not reference itself", () => {
      let node = itemIn(modules(), "Xote.View", "node")
      Assert.combineResults([
        Assert.isFalse(refIds(node)->Array.includes("Xote.View.node")),
        Assert.arrayContains(refIds(node), "Xote.View.attrValue"),
      ])
    }),
    Test.make("no namespace still resolves local types", () => {
      let run = itemIn(modules(), "Probe", "run")
      Assert.equal(refIds(run), ["Probe.conf", "Probe.shape"])
    }),
    Test.make("scopes are innermost first", () => {
      Assert.equal(Refs.scopesOf("Xote.View.For"), ["Xote.View.For", "Xote.View", "Xote"])
    }),
  ],
)

Runner.runSuites([suite])
