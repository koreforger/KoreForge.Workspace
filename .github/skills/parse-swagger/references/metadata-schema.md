# metadata.json schema

The Stage-2 generator (`scr/generate.ps1` inside a KoreForge.SwaggerControllers consumer repo) reads exactly this shape. Anything outside it is ignored or rejected.

## Top-level

```jsonc
{
  "apiName": "Party",            // PascalCase identifier from the path: swaggers/Party/v1/swagger.yml
  "version": 1,                  // integer parsed from "v<N>"
  "basePath": "/aft/party/v1",   // verbatim from swagger.basePath; "" if not set
  "operations": [ /* see below */ ],
  "dtos":       [ /* see below */ ]
}
```

Top-level key order is fixed: `apiName`, `version`, `basePath`, `operations`, `dtos`.

## operations[]

Each entry describes one HTTP operation. Order matches the source-file order of `paths.<route>.<method>` traversal (routes in source order, methods in `get,put,post,delete,patch,head,options` order within a route).

```jsonc
{
  "name": "GetPartyById",                 // C# method name; see naming-conventions.md
  "httpMethod": "GET",                    // upper-case
  "route": "parties/{id}",                // path with leading slash stripped; basePath already on controller
  "summary": "...",                       // verbatim swagger summary; "" when absent
  "parameters": [
    {
      "name": "id",                       // C# camelCase parameter name (from naming-conventions.md)
      "originalName": "id",               // verbatim swagger name (used for route/header binding)
      "in": "path",                       // path|query|header|body|formData
      "required": true,
      "type": "string",                   // C# type expression from type-mapping.md
      "description": ""                   // verbatim swagger description; "" when absent
    }
  ],
  "requestBody": {                        // null if no body parameter
    "type": "PartyRequest",
    "required": true,
    "description": ""
  },
  "responses": [
    {
      "statusCode": 200,                  // integer; "default" maps to 0
      "type": "Party",                    // C# type expression; null when no schema/empty body
      "description": ""
    }
  ],
  "successResponse": {                    // first 2xx response, copied for convenience
    "statusCode": 200,
    "type": "Party"
  },
  "headers": [                            // header parameters extracted for AuthDelegatingHandler awareness
    {
      "name": "xCorrelationId",           // camelCase
      "originalName": "X-Correlation-Id", // verbatim
      "required": false,
      "type": "string",
      "infrastructure": false             // true when name matches X-IBM-Client-Id, X-IBM-Client-Secret, Authorization
    }
  ]
}
```

Inside an operation the key order is fixed: `name`, `httpMethod`, `route`, `summary`, `parameters`, `requestBody`, `responses`, `successResponse`, `headers`.

## dtos[]

Each entry describes one swagger `definition`. Order is alphabetical by `name`.

```jsonc
{
  "name": "Party",
  "summary": "",
  "properties": [
    {
      "name": "Id",                       // PascalCase C# property name (camelCase original is preserved separately)
      "originalName": "id",
      "type": "string",
      "required": true,
      "description": ""
    }
  ]
}
```

Inside a dto the key order is fixed: `name`, `summary`, `properties`.

## Validation rules

The generator rejects metadata.json files that fail any of:

- `apiName` is empty or contains characters outside `[A-Za-z0-9]`.
- `version` is not a positive integer.
- An operation has no `name` or duplicates another operation's `name`.
- A parameter has `in == "body"` and the dto type is missing from `dtos[]`.
- A response references a `type` that is not `null`, a primitive, an array of one of these, nor a name in `dtos[]`.

## Example

See `references/example.metadata.json` (kept under this folder once Phase 4 ships fixtures).
