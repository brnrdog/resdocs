/* Runs the ReScript compiler and `rescript-tools doc` for a project,
   using the `rescript` package that project has installed. */

type t = {bins: Node.bins, projectDir: string}

let locate = async (projectDir: string): result<t, string> =>
  switch Node.findPackageDir(projectDir, "rescript")->Nullable.toOption {
  | None => Error("cannot find the rescript package from " ++ projectDir ++ ", run npm install first")
  | Some(rescriptDir) =>
    let bins = await Node.rescriptBins(rescriptDir)
    Ok({bins, projectDir})
  }

let isBuilt = (projectDir: string): bool => Node.existsSync(Node.join([projectDir, "lib", "bs"]))

let build = (tools: t): result<unit, string> => {
  let result = Node.run(tools.bins.rescript, ["build"], ~cwd=tools.projectDir)
  switch result.status->Nullable.toOption {
  | Some(0) => Ok()
  | _ => Error("rescript build failed:\n" ++ result.stdout ++ result.stderr)
  }
}

/* Raw JSON for one file, or an error. An empty output means the tool
   found no build artifacts for the file. */
let doc = (tools: t, file: string): result<string, string> => {
  let result = Node.run(tools.bins.tools, ["doc", file], ~cwd=tools.projectDir)
  switch result.status->Nullable.toOption {
  | Some(0) if result.stdout->String.trim != "" => Ok(result.stdout)
  | Some(0) => Error("no output for " ++ file ++ " (is the project compiled?)")
  | _ => Error("rescript-tools doc failed for " ++ file ++ ":\n" ++ result.stderr)
  }
}
