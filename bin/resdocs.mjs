#!/usr/bin/env node
import { main } from "../src/cli/Cli.res.mjs";

main(process.argv.slice(2)).then(
  code => process.exit(code),
  error => {
    console.error(error);
    process.exit(1);
  },
);
