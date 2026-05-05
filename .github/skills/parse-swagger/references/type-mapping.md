# Type mapping

Swagger 2.0 types and `$ref` references are translated to C# type expressions and stored in `metadata.json`. The mapping is total: every input shape produces exactly one output expression.

## Primitives

| Swagger `type` | Swagger `format` | C# expression |
|---|---|---|
| `string` | (none, `password`)              | `string` |
| `string` | `byte`                          | `byte[]` |
| `string` | `binary`                        | `Stream` |
| `string` | `date`                          | `DateOnly` |
| `string` | `date-time`                     | `DateTimeOffset` |
| `string` | `uuid`, `guid`                  | `Guid` |
| `string` | `uri`                           | `Uri` |
| `integer` | (none, `int32`)                | `int` |
| `integer` | `int64`                        | `long` |
| `number`  | (none, `double`)               | `double` |
| `number`  | `float`                        | `float` |
| `number`  | `decimal`                      | `decimal` |
| `boolean` | —                              | `bool` |
| `file`    | —                              | `Stream` |

## Nullability

- A property/parameter that is **not** in the schema's `required` array is emitted with a trailing `?` for value types: `int` → `int?`, `bool` → `bool?`, `DateTimeOffset` → `DateTimeOffset?`. Reference types stay un-suffixed (the generator opts in to nullable reference types).
- A required value-type stays unsuffixed.

## Arrays

`type: array, items: <X>` → `IReadOnlyList<<X>>` where `<X>` is the recursively mapped expression. Arrays are never `null` — an absent field is materialized as `Array.Empty<X>()` by the generator. `metadata.json` records the type as `IReadOnlyList<T>` regardless of nullability.

## Objects with `$ref`

`{"$ref": "#/definitions/Party"}` → `Party`. Cross-file `$ref` is **not supported**; the skill must fail if it sees one.

## Inline objects

A schema with `type: object` and inline `properties` is **not supported** at the top level of a definition. The skill should fail with `inline object schemas are not supported; promote to a named definition`.

For inline objects nested inside arrays or other definitions, emit `Dictionary<string, object>` only as a last resort and add `"description": "WARN: inline object replaced with Dictionary<string,object>"` on the property. Prefer to fail.

## additionalProperties

`type: object, additionalProperties: { ... }` → `IReadOnlyDictionary<string, <mapped>>`.
`type: object, additionalProperties: true` → `IReadOnlyDictionary<string, object>`.

## allOf

A definition that uses `allOf` to merge a `$ref` and an inline schema is flattened: the `$ref`'d definition's properties are inherited and the inline ones are appended. The skill emits a single dto with the merged property list. The skill must not emit a base/derived hierarchy.

## enum

`type: string, enum: ["A", "B"]` → emit `string` and add `"description": "values: A,B"` on the property/parameter. The generator does not produce C# enums (string parameters keep upstream tolerance to new values).

## Empty / void responses

Operations with a 2xx response that has no `schema` block emit `successResponse.type = null`. The generator binds these to `Outcome<Unit>`.

## Failure modes

The skill must fail (no `metadata.json` written) when it encounters any of:

- `swagger:` is not `"2.0"`.
- A `$ref` that is not `#/definitions/<TypeName>` (cross-file or non-`definitions` references).
- A definition with `type: object` and no `properties` and no `additionalProperties` (cannot determine shape).
- A response with both no `schema` and a non-2xx status that is referenced by `successResponse`.
- An operation with no `operationId`.

Each failure is a single-line stderr message of the form `parse-swagger: <reason> at <path/in/swagger>`.
