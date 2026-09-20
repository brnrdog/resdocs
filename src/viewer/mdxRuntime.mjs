// Runs a precompiled MDX function body against xote's JSX runtime.
// This is what `runSync` from @mdx-js/mdx does, inlined so the viewer
// does not pull the compiler into its bundle.
import * as runtime from "xote/jsx-runtime";

export function runDoc(code) {
  return new Function(String(code))({ ...runtime, baseUrl: "file:///" }).default;
}
