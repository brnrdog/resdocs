open Zekr

let suite = Suite.make(
  "Recently viewed",
  [
    Test.make("newest first, without duplicates", () =>
      Assert.equal(Recent.add(["a", "b", "c"], "b"), ["b", "a", "c"])
    ),
    Test.make("capped at the limit", () => {
      let many = Array.fromInitializer(~length=Recent.limit, i => Int.toString(i))
      let next = Recent.add(many, "new")
      Assert.combineResults([
        Assert.equal(Array.length(next), Recent.limit),
        Assert.equal(next->Array.get(0), Some("new")),
        Assert.isFalse(next->Array.includes(Int.toString(Recent.limit - 1))),
      ])
    }),
    Test.make("storage round trips and tolerates garbage", () =>
      Assert.combineResults([
        Assert.equal(Recent.decode(Some(Recent.encode(["x", "y"]))), ["x", "y"]),
        Assert.equal(Recent.decode(None), []),
        Assert.equal(Recent.decode(Some("not json")), []),
        Assert.equal(Recent.decode(Some("{\"a\":1}")), []),
        Assert.equal(Recent.decode(Some("[\"ok\", 3, null]")), ["ok"]),
      ])
    ),
  ],
)

Runner.runSuites([suite])
