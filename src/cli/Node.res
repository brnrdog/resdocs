/* Bindings to the Node APIs the CLI needs. */

@module("node:fs")
external readFileSync: (string, @as("utf8") _) => string = "readFileSync"
@module("node:fs") external writeFileSync: (string, string) => unit = "writeFileSync"
@module("node:fs") external existsSync: string => bool = "existsSync"

type mkdirOptions = {recursive: bool}
@module("node:fs") external mkdirSync: (string, mkdirOptions) => unit = "mkdirSync"
@module("node:fs") external readdirSync: string => array<string> = "readdirSync"

type stats
@module("node:fs") external statSync: string => stats = "statSync"
@send external isDirectory: stats => bool = "isDirectory"

@module("node:path") @variadic external join: array<string> => string = "join"
@module("node:path") external resolve: (string, string) => string = "resolve"
@module("node:path") external dirname: string => string = "dirname"
@module("node:path") external basename: string => string = "basename"
@module("node:path") external relative: (string, string) => string = "relative"

type spawnOptions = {cwd: string, encoding: string, maxBuffer: int}
type spawnResult = {status: Nullable.t<int>, stdout: string, stderr: string}
@module("node:child_process")
external spawnSync: (string, array<string>, spawnOptions) => spawnResult = "spawnSync"

@val @scope("process") external execPath: string = "execPath"
@val @scope("process") external cwd: unit => string = "cwd"
@val @scope("process") external exit: int => unit = "exit"
@val @scope(("process", "stderr")) external writeStderr: string => unit = "write"
@val @scope(("process", "stdout")) external writeStdout: string => unit = "write"

let log = (line: string) => writeStdout(line ++ "\n")
let warn = (line: string) => writeStderr(line ++ "\n")

let mkdirp = (dir: string) => mkdirSync(dir, {recursive: true})

let run = (command: string, args: array<string>, ~cwd: string): spawnResult =>
  spawnSync(command, args, {cwd, encoding: "utf8", maxBuffer: 256 * 1024 * 1024})

/* helpers.mjs */
@module("./helpers.mjs") external packageRoot: string = "packageRoot"
@module("./helpers.mjs")
external findPackageDir: (string, string) => Nullable.t<string> = "findPackageDir"

type bins = {tools: string, rescript: string}
@module("./helpers.mjs") external rescriptBins: string => promise<bins> = "rescriptBins"
@module("./helpers.mjs")
external compileDoc: string => promise<Nullable.t<string>> = "compileDoc"
@module("./helpers.mjs") external copyDir: (string, string) => unit = "copyDir"
@module("./helpers.mjs") external nowIso: unit => string = "nowIso"
