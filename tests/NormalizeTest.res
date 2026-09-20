open Zekr

let probe = () => Normalize.ofDoc(Docgen.parse(NodeFs.readFixture("probe.json")))
let view = () => Normalize.ofDoc(Docgen.parse(NodeFs.readFixture("xote-View.json")))
let router = () => Normalize.ofDoc(Docgen.parse(NodeFs.readFixture("xote-Router.json")))

let findType = (m: Bundle.module_, name) => m.types->Array.find(t => t.name == name)
let findValue = (m: Bundle.module_, name) => m.values->Array.find(t => t.name == name)
let findModule = (m: Bundle.module_, name) => m.modules->Array.find(t => t.name == name)

let suite = Suite.make(
  "Normalize",
  [
    Test.make("file module without namespace keeps its bare name", () => {
      let m = probe()
      Assert.combineResults([
        Assert.equal(m.id, "Probe"),
        Assert.equal(m.name, "Probe"),
        Assert.equal(m.anchor, "top"),
        Assert.equal(m.source.file, "src/Probe.res"),
      ])
    }),
    Test.make("namespace is taken from the tool's module name", () => {
      let m = view()
      Assert.combineResults([
        Assert.equal(m.id, "Xote.View"),
        Assert.equal(m.name, "View"),
        Assert.equal(m.source.file, "src/View.resi"),
        Assert.equal(Normalize.namespaceOf(Docgen.parse(NodeFs.readFixture("xote-View.json"))), Some("Xote")),
      ])
    }),
    Test.make("an explicit namespace overrides the inferred one", () => {
      let m = Normalize.ofDoc(~namespace="Custom", Docgen.parse(NodeFs.readFixture("probe.json")))
      Assert.equal(m.id, "Custom.Probe")
    }),
    Test.make("types and values are split and keep source order", () => {
      let m = probe()
      Assert.combineResults([
        Assert.equal(m.types->Array.map(t => t.name), ["conf", "shape"]),
        Assert.equal(m.values->Array.map(v => v.name), ["run", "old"]),
        Assert.equal(m.modules->Array.map(v => v.name), ["Inner", "S", "Alias"]),
      ])
    }),
    Test.make("ids and anchors come from nesting", () => {
      let m = probe()
      let inner = findModule(m, "Inner")->Option.getOrThrow
      let make = findValue(inner, "make")->Option.getOrThrow
      let run = findValue(m, "run")->Option.getOrThrow
      let conf = findType(m, "conf")->Option.getOrThrow
      Assert.combineResults([
        Assert.equal(run.anchor, "value-run"),
        Assert.equal(conf.id, "Probe.conf"),
        Assert.equal(inner.id, "Probe.Inner"),
        Assert.equal(inner.anchor, "module-Inner"),
        Assert.equal(make.id, "Probe.Inner.make"),
        Assert.equal(make.anchor, "value-Inner-make"),
      ])
    }),
    Test.make("nested alias id is computed, not taken from the tool", () => {
      let m = router()
      let link = findModule(m, "Link")->Option.getOrThrow
      let prop = findModule(link, "Prop")->Option.getOrThrow
      Assert.combineResults([
        Assert.equal(prop.id, "Xote.Router.Link.Prop"),
        Assert.equal(prop.kind, Bundle.Alias),
        Assert.equal(prop.anchor, "module-Link-Prop"),
      ])
    }),
    Test.make("docstrings are joined and trimmed", () => {
      let m = probe()
      let run = findValue(m, "run")->Option.getOrThrow
      let inner = findModule(m, "Inner")->Option.getOrThrow
      let t = findType(inner, "t")->Option.getOrThrow
      Assert.combineResults([
        Assert.equal(run.doc, "Doc for `run`."),
        Assert.equal(inner.doc, "Nested module docs"),
        Assert.equal(t.doc, "inner type"),
        Assert.equal(run.docCode, None),
      ])
    }),
    Test.make("record detail keeps optional fields", () => {
      let m = probe()
      let conf = findType(m, "conf")->Option.getOrThrow
      switch conf.detail {
      | Record({fields}) =>
        Assert.combineResults([
          Assert.equal(fields->Array.map(f => f.name), ["name", "count", "next"]),
          Assert.equal(fields->Array.map(f => f.optional), [false, true, false]),
          Assert.equal((fields->Array.getUnsafe(1)).signature, "option<int>"),
        ])
      | _ => Fail("expected a record")
      }
    }),
    Test.make("variant detail keeps inline record payloads", () => {
      let m = probe()
      let shape = findType(m, "shape")->Option.getOrThrow
      switch shape.detail {
      | Variant({constructors}) =>
        let c = constructors->Array.getUnsafe(2)
        Assert.combineResults([
          Assert.equal(constructors->Array.map(c => c.name), ["A", "B", "C"]),
          Assert.equal(c.signature, "C({w: float, h: float})"),
          Assert.equal(c.fields->Array.map(f => f.name), ["w", "h"]),
          Assert.equal((constructors->Array.getUnsafe(0)).fields, []),
        ])
      | _ => Fail("expected a variant")
      }
    }),
    Test.make("abstract types and values have no detail", () => {
      let m = probe()
      let inner = findModule(m, "Inner")->Option.getOrThrow
      let t = findType(inner, "t")->Option.getOrThrow
      let run = findValue(m, "run")->Option.getOrThrow
      Assert.combineResults([
        Assert.equal(t.detail, Bundle.Abstract),
        Assert.equal(run.detail, Bundle.Abstract),
      ])
    }),
    Test.make("deprecated is carried through", () => {
      let m = probe()
      let old = findValue(m, "old")->Option.getOrThrow
      let run = findValue(m, "run")->Option.getOrThrow
      Assert.combineResults([
        Assert.equal(old.deprecated, Some("Use run")),
        Assert.equal(run.deprecated, None),
        Assert.equal(m.deprecated, None),
      ])
    }),
    Test.make("module types and aliases are marked", () => {
      let m = probe()
      let s = findModule(m, "S")->Option.getOrThrow
      let alias = findModule(m, "Alias")->Option.getOrThrow
      let inner = findModule(m, "Inner")->Option.getOrThrow
      Assert.combineResults([
        Assert.equal(s.kind, Bundle.ModuleType),
        Assert.equal(alias.kind, Bundle.Alias),
        Assert.equal(inner.kind, Bundle.Module),
      ])
    }),
    Test.make("signature is kept verbatim", () => {
      let m = view()
      let element = findValue(m, "element")->Option.getOrThrow
      Assert.isTrue(element.signature->String.startsWith("let element: (\n  string,\n  ~attrs:"))
    }),
    Test.make("bundle round trips through JSON", () => {
      let bundle: Bundle.bundle = {
        version: Bundle.version,
        package: "probe",
        namespace: None,
        title: "probe",
        repo: None,
        generatedAt: "now",
        modules: Refs.apply([probe()]),
      }
      let back = Bundle.parse(Bundle.stringify(bundle))
      Assert.combineResults([
        Assert.equal(back.namespace, None),
        Assert.equal(Bundle.stringify(back), Bundle.stringify(bundle)),
        Assert.equal(Bundle.findModule(back, "Probe.Inner")->Option.map(m => m.name), Some("Inner")),
        Assert.equal(Bundle.topModuleOf(back, "Probe.Inner.make")->Option.map(m => m.id), Some("Probe")),
      ])
    }),
    Test.make("glob patterns", () => {
      Assert.combineResults([
        Assert.isTrue(Normalize.matchesPattern("Runtime*", "RuntimeDom")),
        Assert.isFalse(Normalize.matchesPattern("Runtime*", "View")),
        Assert.isTrue(Normalize.matchesPattern("*Test", "FooTest")),
        Assert.isTrue(Normalize.matchesPattern("View", "View")),
        Assert.isFalse(Normalize.matchesPattern("View", "Views")),
        Assert.isTrue(Normalize.matchesPattern("A*B*C", "AxxBzzC")),
        Assert.isFalse(Normalize.matchesPattern("A*B*C", "AxxCzzB")),
      ])
    }),
    Test.make("source url is built from the repo config", () => {
      let bundle: Bundle.bundle = {
        version: 1,
        package: "p",
        namespace: None,
        title: "p",
        repo: Some({url: "https://github.com/o/r", ref: "main", dir: "packages/p"}),
        generatedAt: "",
        modules: [],
      }
      Assert.equal(
        Bundle.sourceUrl(bundle, {file: "src/A.res", line: 7}),
        Some("https://github.com/o/r/blob/main/packages/p/src/A.res#L7"),
      )
    }),
  ],
)

Runner.runSuites([suite])
