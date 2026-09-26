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

/* Parsed with the same helper and sanitizer the CLI uses. */
@module("../src/cli/helpers.mjs")
external parseDocRaw: string => array<Doc.node> = "parseDoc"

let parseDoc = text => Some(Doc.sanitize(parseDocRaw(text)))

let renderDoc = text => {
  let html = mountNode(Markdown.render(~tree=parseDoc(text), ~fallback="raw"))->innerHTML
  DomTesting.cleanup()
  html
}

let item = (~signature, ~refs): Bundle.item => {
  id: "Probe.run",
  anchor: "value-run",
  kind: Value,
  name: "run",
  signature,
  doc: "",
  docTree: None,
  deprecated: None,
  source: {file: "src/Probe.res", line: 1},
  detail: Abstract,
  refs,
}

let bundleWith = (modules): Bundle.bundle => {
  version: 1,
  package: "probe",
  packageVersion: "",
  description: "",
  namespace: None,
  title: "probe",
  hub: None,
  repo: None,
  generatedAt: "",
  modules,
}

let suite = Suite.async(
  "Viewer rendering",
  [
    Test.async("markdown renders with GFM and highlighting", async () => {
      let html = renderDoc(
        "Doc for `run`.\n\n- one\n- two\n\n```rescript\nlet x = A\n```\n\n| a | b |\n|---|---|\n| 1 | 2 |",
      )
      Assert.combineResults([
        Assert.contains(html, "<p>Doc for <code>run</code>.</p>"),
        Assert.contains(html, "<li>one</li>"),
        Assert.contains(html, "<code class=\"language-rescript\"><span class=\"tok-keyword\">let</span>"),
        Assert.contains(html, "<span class=\"tok-type\">A</span>"),
        Assert.contains(html, "<table>"),
      ])
    }),
    Test.async("markdown falls back to plain text without code", async () => {
      let html = mountNode(Markdown.render(~tree=None, ~fallback="a < b"))->innerHTML
      let empty = mountNode(Markdown.render(~tree=None, ~fallback=""))->innerHTML
      DomTesting.cleanup()
      Assert.combineResults([
        Assert.equal(html, "<pre class=\"doc-plain\">a &lt; b</pre>"),
        Assert.equal(empty, ""),
      ])
    }),
    Test.async("docstrings are never evaluated", async () => {
      let html = renderDoc("Hi {globalThis.pwned = 1} and <script>alert(1)</script> <img src=x onerror=alert(1)>")
      Assert.combineResults([
        Assert.isFalse(%raw(`globalThis.pwned === 1`)),
        Assert.contains(html, "Hi {globalThis.pwned = 1} and &lt;script&gt;alert(1)&lt;/script&gt;"),
        Assert.contains(html, "&lt;img src=x onerror=alert(1)&gt;"),
        Assert.isFalse(html->String.includes("<script")),
        Assert.isFalse(html->String.includes("<img")),
      ])
    }),
    Test.async("links keep safe URLs only", async () => {
      let html = renderDoc(
        "[a](javascript:alert(1)) [b](JAVASCRIPT:alert(1)) [c](data:text/html,x) [g](jav&#x09;ascript:x) [d](https://rescript-lang.org) [e](#type-t) [f](./Other.res)",
      )
      Assert.combineResults([
        Assert.isFalse(html->String.toLowerCase->String.includes("href=\"j")),
        Assert.isFalse(html->String.includes("href=\"data")),
        Assert.contains(html, "<a>a</a>"),
        Assert.contains(html, "<a href=\"https://rescript-lang.org\">d</a>"),
        Assert.contains(html, "<a href=\"#type-t\">e</a>"),
        Assert.contains(html, "<a href=\"./Other.res\">f</a>"),
      ])
    }),
    Test.async("urls with hidden schemes are unsafe", async () =>
      Assert.combineResults([
        Assert.isFalse(Doc.isSafeUrl("java\tscript:alert(1)")),
        Assert.isFalse(Doc.isSafeUrl(" \njavascript:alert(1)")),
        Assert.isFalse(Doc.isSafeUrl("vbscript:x")),
        Assert.isTrue(Doc.isSafeUrl("mailto:a@b.c")),
        Assert.isTrue(Doc.isSafeUrl("Module#value-x:y")),
        Assert.isTrue(Doc.isSafeUrl("../a?b=c:d")),
      ])
    ),
    Test.async("a hand-edited bundle tree is sanitized in the viewer", async () => {
      let tree: array<Doc.node> = [
        Element({tag: "script", attrs: [], children: [Text({value: "alert(1)"})]}),
        Element({
          tag: "a",
          attrs: [("href", "javascript:alert(1)"), ("onclick", "alert(1)"), ("title", "t")],
          children: [Text({value: "link"})],
        }),
        Element({tag: "iframe", attrs: [("src", "https://example.com")], children: []}),
      ]
      let html = mountNode(Markdown.render(~tree=Some(tree), ~fallback="raw"))->innerHTML
      DomTesting.cleanup()
      Assert.equal(html, "alert(1)<a title=\"t\">link</a>")
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
    Test.async("pages pre-render with their content, links and not-found state", async () => {
      let bundle = bundleWith(
        Refs.apply([Normalize.ofDoc(Docgen.parse(NodeFs.readFixture("probe.json")))]),
      )
      let home = Prerender.render(bundle, ~pathname="/")
      let page = Prerender.render(bundle, ~pathname="/module/Probe")
      let slash = Prerender.render(bundle, ~pathname="/module/Probe/")
      let missing = Prerender.render(bundle, ~pathname="/module/Nope")
      Assert.combineResults([
        Assert.contains(home, "href=\"/module/Probe\""),
        Assert.contains(page, "id=\"value-run\""),
        Assert.contains(page, "<a class=\"ref\" href=\"/module/Probe#type-conf\">conf</a>"),
        Assert.contains(page, "aria-current=\"page\""),
        Assert.equal(slash, page),
        Assert.contains(missing, "No such module."),
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
