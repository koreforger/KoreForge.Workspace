# Naming conventions

Applied by the `parse-swagger` skill when emitting `metadata.json` and consumed verbatim by `scr/generate.ps1`. Identical inputs must always produce identical names.

## API identifier (`apiName`)

Taken verbatim from the path segment `swaggers/<ApiName>/...`. Preserve case. Do **not** transform from `kebab-case` or `snake_case` — the source-of-truth swagger location is authoritative. If the upstream swagger uses an awkward casing, rename the directory once, never re-case at parse time.

## Version (`v<N>`)

Integer N. Used to suffix every generated namespace (`...V<N>`) and the URL segment (`v<N>`).

## Operation method names (`operations[].name`)

Source: `operationId` on the swagger operation.

1. If `operationId` is missing — **fail**. The skill does not invent operation names.
2. Strip any prefix that duplicates the `apiName` (case-insensitive). Examples:
   - `Party_GetPartyById` → `GetPartyById`
   - `partyGetById` → `GetById` (only when the prefix is the literal apiName).
3. Convert separators (`-`, `_`, `.`) to PascalCase boundaries: `get-party-by-id` → `GetPartyById`.
4. Capitalize the first character.
5. Verbs stay verbs; do **not** map `Get` → `Fetch` or similar.

The resulting name must be a valid C# identifier and unique within the API.

## Route segments

The generator emits `[Route("api/<api-name>/v<N>/...")]` on the controller and `[Http<Verb>("<remainder>")]` on each action.

- `<api-name>` is `apiName` lower-cased, with internal capitals separated by hyphens (`PartyAccount` → `party-account`). Acronyms ≥ 2 capitals stay together (`SASVIFinancialCrimeCaseManagement` → `sasvi-financial-crime-case-management`; treat acronyms as single tokens by splitting only on the *trailing* lowercase boundary).
- `metadata.operations[].route` is the swagger path with the leading `/` stripped and the swagger `basePath` removed if it duplicates the controller route.
- Path parameters keep their swagger `originalName` between braces (`{id}`).

## Parameter names

`metadata.parameters[].name` is the C# identifier. `originalName` is the swagger name preserved for binding.

- `path`, `query`, `formData` parameters: convert `originalName` to `camelCase` (split on `-`, `_`, then lower-first PascalCase).
- `header` parameters: same camelCase rule, **and** set `infrastructure: true` when `originalName` matches (case-insensitive) any of:
  - `X-IBM-Client-Id`
  - `X-IBM-Client-Secret`
  - `Authorization`
- `body` parameters: drop the original name; the generator binds the body to a parameter named `request`.

## DTO type names (`dtos[].name`)

Take the swagger `definitions.<TypeName>` key verbatim. If two definitions differ only by case, fail.

## DTO property names (`dtos[].properties[].name`)

PascalCase the swagger property `originalName` (split on `-`, `_`, `.`). Acronyms keep capitals (`Id`, `URL` stays `URL`). Preserve `originalName` separately so the generator can emit `[JsonPropertyName(...)]` only when names differ.

## Determinism

Within `operations[]`, ordering is **source order** — the order in which paths and methods appear in the input file. Do not sort.

Within `dtos[]`, ordering is **alphabetical by `name`** (ordinal, case-sensitive).

Within `properties[]` and `parameters[]`, ordering is **source order**.
