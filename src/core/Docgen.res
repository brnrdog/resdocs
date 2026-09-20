/* Types for the JSON printed by `rescript-tools doc`.

   Derived from real output, see docs/api-survey.md section 3 and
   the samples under docs/survey. The shapes mirror the decoder that
   ships with @rescript/tools, minus fields that never appear. */

type source = {filepath: string, line: int, col: int}

type field = {
  name: string,
  docstrings: array<string>,
  signature: string,
  optional: bool,
  deprecated?: string,
}

@tag("kind")
type constructorPayload =
  | @as("inlineRecord") InlineRecord({fields: array<field>})

type constructor = {
  name: string,
  docstrings: array<string>,
  signature: string,
  deprecated?: string,
  payload?: constructorPayload,
}

type rec typeInSignature = {
  path: string,
  genericTypeParameters?: array<typeInSignature>,
}

/* Lossy: labels are dropped and function typed parameters are
   flattened. Kept for completeness, not used for rendering. */
type signatureDetails = {
  parameters?: array<typeInSignature>,
  returnType: typeInSignature,
}

@tag("kind")
type detail =
  | @as("record") Record({items: array<field>})
  | @as("variant") Variant({items: array<constructor>})
  | @as("signature") Signature({details: signatureDetails})

@tag("kind")
type rec item =
  | @as("value")
  Value({
      id: string,
      docstrings: array<string>,
      signature: string,
      name: string,
      deprecated?: string,
      source: source,
      detail?: detail,
    })
  | @as("type")
  Type({
      id: string,
      docstrings: array<string>,
      signature: string,
      name: string,
      deprecated?: string,
      source: source,
      detail?: detail,
    })
  | @as("module")
  Module({
      id: string,
      docstrings: array<string>,
      deprecated?: string,
      name: string,
      source: source,
      items: array<item>,
    })
  | @as("moduleType")
  ModuleType({
      id: string,
      docstrings: array<string>,
      deprecated?: string,
      name: string,
      source: source,
      items: array<item>,
    })
  | @as("moduleAlias")
  ModuleAlias({
      id: string,
      docstrings: array<string>,
      name: string,
      source: source,
      items: array<item>,
    })

/* The top level carries `deprecated: null` rather than omitting it. */
type doc = {
  name: string,
  deprecated: Nullable.t<string>,
  docstrings: array<string>,
  source: source,
  items: array<item>,
}

external fromJson: JSON.t => doc = "%identity"

let parse = (text: string): doc => JSON.parseOrThrow(text)->fromJson
