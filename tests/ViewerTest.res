open Zekr
open Xote

/* zekr installs jsdom's window as a global; xote's renderer reads
   `document` directly, so expose it too. */
let exposeDocument: unit => unit = %raw(`function () {
  var win = globalThis.__zekr_window
  if (win && typeof globalThis.document === "undefined") {
    globalThis.window = win
    globalThis.document = win.document
  }
}`)

/* Renders a node into a jsdom container provided by zekr. */
let mountNode = (node: View.node): Dom.element => {
  let {container} = DomTesting.render("")
  exposeDocument()
  View.mount(node, container)
  container
}

Router.initSSR(~pathname="/", ())

@get external innerHTML: Dom.element => string = "innerHTML"

/* Compiled with the same helper the CLI uses. */
@module("../src/cli/helpers.mjs")
external compileDoc: string => promise<Nullable.t<string>> = "compileDoc"

let item = (~signature, ~refs): Bundle.item => {
  id: "Probe.run",
  anchor: "value-run",
  kind: Value,
  name: "run",
  signature,
  doc: "",
  docCode: None,
  deprecated: None,
  source: {file: "src/Probe.res", line: 1},
  detail: Abstract,
  refs,
}

let bundleWith = (modules): Bundle.bundle => {
  version: 1,
  package: "probe",
  namespace: None,
  title: "probe",
  repo: None,
  generatedAt: "",
  modules,
}

let suite = Suite.async(
  "Viewer rendering",
  [
    Test.async("markdown renders through MDX with GFM and highlighting", async () => {
      let code = await compileDoc("Doc for `run`.\n\n- one\n- two\n\n```rescript\nlet x = A\n```\n\n| a | b |\n|---|---|\n| 1 | 2 |")
      let html = mountNode(Markdown.render(~code=code->Nullable.toOption, ~fallback="raw"))->innerHTML
      DomTesting.cleanup()
      Assert.combineResults([
        Assert.contains(html, "<p>Doc for <code>run</code>.</p>"),
        Assert.contains(html, "<li>one</li>"),
        Assert.contains(html, "<code class=\"language-rescript\"><span class=\"tok-keyword\">let</span>"),
        Assert.contains(html, "<span class=\"tok-type\">A</span>"),
        Assert.contains(html, "<table>"),
      ])
    }),
    Test.async("markdown falls back to plain text without code", async () => {
      let html = mountNode(Markdown.render(~code=None, ~fallback="a < b"))->innerHTML
      let empty = mountNode(Markdown.render(~code=None, ~fallback=""))->innerHTML
      DomTesting.cleanup()
      Assert.combineResults([
        Assert.equal(html, "<pre class=\"doc-plain\">a &lt; b</pre>"),
        Assert.equal(empty, ""),
      ])
    }),
    Test.async("invalid MDX is rejected by the compiler", async () => {
      let code = await compileDoc("unbalanced <div>")
      Assert.equal(code->Nullable.toOption, None)
    }),
    Test.async("signature links resolved names and highlights the rest", async () => {
      Signal.set(
        Store.bundle,
        Some(
          bundleWith(
            Refs.apply([Normalize.ofDoc(Docgen.parse(NodeFs.readFixture("probe.json")))]),
          ),
        ),
      )
      let node = Signature.render(
        item(
          ~signature="let run: (~label: string, array<conf>) => shape",
          ~refs=[{name: "conf", id: "Probe.conf"}, {name: "shape", id: "Probe.shape"}],
        ),
      )
      let html = mountNode(node)->innerHTML
      DomTesting.cleanup()
      Assert.combineResults([
        Assert.contains(html, "<span class=\"tok-keyword\">let</span> run: ("),
        Assert.contains(html, "<span class=\"tok-label\">~label</span>: string"),
        Assert.contains(html, "<a class=\"ref\" href=\"/module/Probe#type-conf\">conf</a>"),
        Assert.contains(html, "<a class=\"ref\" href=\"/module/Probe#type-shape\">shape</a>"),
        Assert.isFalse(html->String.includes("href=\"/module/Probe#type-string")),
      ])
    }),
    Test.async("highlighter covers strings, comments, attributes and numbers", async () => {
      let html = mountNode(View.fragment(Highlight.highlight("@deprecated(\"x\") let n = 42 // c")))->innerHTML
      DomTesting.cleanup()
      Assert.combineResults([
        Assert.contains(html, "<span class=\"tok-attr\">@deprecated</span>"),
        Assert.contains(html, "<span class=\"tok-string\">\"x\"</span>"),
        Assert.contains(html, "<span class=\"tok-number\">42</span>"),
        Assert.contains(html, "<span class=\"tok-comment\">// c</span>"),
      ])
    }),
  ],
)

Runner.runAsyncSuites([suite])->ignore
