open Zekr

let suite = Suite.make(
  "SigTokens",
  [
    Test.make("words are type paths, labels and fields are not", () => {
      let sig = "let element: (\n  string,\n  ~attrs: array<(string, attrValue)>=?,\n  unit,\n) => node"
      Assert.equal(SigTokens.words(sig), ["string", "array", "string", "attrValue", "unit", "node"])
    }),
    Test.make("qualified paths and type variables", () => {
      let sig = "type props<'item> = {each: Xote.MaybeSignal.t<array<'item>>, by?: 'item => string}"
      Assert.equal(SigTokens.words(sig), ["props", "Xote.MaybeSignal.t", "array", "string"])
    }),
    Test.make("keywords and constructors are not words", () => {
      let sig = "type t = Xote.RuntimeNode.attrValue =\n  | Static(string)\n  | Compute(unit => string)"
      Assert.equal(SigTokens.words(sig), ["t", "Xote.RuntimeNode.attrValue", "string", "unit", "string"])
    }),
    Test.make("tokenize covers the whole string", () => {
      let sig = "let make: props<'item> => node"
      let joined =
        SigTokens.tokenize(sig)
        ->Array.map(t =>
          switch t {
          | Word(w) => w
          | Other(o) => o
          }
        )
        ->Array.join("")
      Assert.combineResults([
        Assert.equal(joined, sig),
        Assert.equal(SigTokens.tokenize(sig)->Array.length, 5),
      ])
    }),
  ],
)

Runner.runSuites([suite])
