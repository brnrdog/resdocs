@module("node:fs") external readFileSync: (string, @as("utf8") _) => string = "readFileSync"

let readFixture = (name: string): string => readFileSync("tests/fixtures/" ++ name)
