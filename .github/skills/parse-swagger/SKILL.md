---
name: parse-swagger
description: Use when converting a Swagger 2.0 file (`swaggers/<ApiName>/v<N>/swagger.yml`) into the canonical `metadata.json` consumed by the KoreForge.SwaggerControllers Stage-2 generator. Read the swagger, apply naming and type rules from the references, write `metadata.json` next to the swagger. Do not generate any C# — that is Stage 2's job.
---

# parse-swagger SKILL

## When to use

Use this skill when **all** of these are true:

- A KoreForge.SwaggerControllers consumer repo has a new or updated file under `swaggers/<ApiName>/v<N>/swagger.{yml,yaml,json}`.
- The matching `swaggers/<ApiName>/v<N>/metadata.json` is missing or out of date.
- The user wants to (re)generate controllers for that API.

Do **not** use this skill for:

- OpenAPI 3.x inputs (the generator and skill are Swagger 2.0 only).
- Editing `metadata.json` by hand.
- Code generation (that is `scr/generate.ps1`'s responsibility).

## Inputs

A single absolute or repo-relative path to one swagger file. The path **must** match the regex:

```text
swaggers/(?<ApiName>[A-Z][A-Za-z0-9]+)/v(?<Version>[0-9]+)/swagger\.(yml|yaml|json)
```

`<ApiName>` is the source-of-truth API identifier and is preserved verbatim into all generated namespaces, type names, and route segments.

## Outputs

Exactly one file:

```text
swaggers/<ApiName>/v<N>/metadata.json
```

The file shape is documented in [references/metadata-schema.md](references/metadata-schema.md). The skill must:

1. Be **deterministic** — the same swagger always produces the same metadata.json (same key order, same array order, same casing).
2. Be **complete** — every operation in the swagger must appear in `operations[]`; every distinct schema must appear in `dtos[]`.
3. Be **side-effect-free** beyond writing the single output file. Do not modify the swagger. Do not write logs. Do not touch `src/`.

## Procedure

1. Read the input file. Detect format from extension.
2. Validate `swagger: "2.0"` is set. If not, fail with a single-line error.
3. Compute `apiName` and `version` from the path regex above. Fail if the path does not match.
4. Walk `paths.<route>.<method>` in the order they appear in the source. Apply [references/naming-conventions.md](references/naming-conventions.md) to derive each operation's C# method name and route segments.
5. Walk `definitions.<TypeName>`. Apply [references/type-mapping.md](references/type-mapping.md) to translate every property and `$ref` into a C# type expression.
6. Emit `metadata.json` using stable key order: `apiName`, `version`, `basePath`, `operations`, `dtos`. Inside each operation, key order is fixed (see schema doc). Pretty-print with 2-space indent, trailing newline.
7. If the output file would be byte-identical to an existing `metadata.json`, leave the file untouched (no mtime bump).

## Acceptance

A run of this skill is acceptable iff:

- Exit cleanly with the single-line message `wrote <relative path>` (or `unchanged <relative path>`).
- The output validates against [references/metadata-schema.md](references/metadata-schema.md).
- Re-running on the same input produces no diff.

## Out of scope

- Resolving cross-file `$ref` (the generator and consumers may refuse such inputs).
- Inferring missing `operationId` values — fail fast if absent.
- Producing example/sample data, request body samples, or test fixtures.
