# KoreForge.Jex — API Reference

**Package**: `KoreForge.Jex`  |  **Assembly**: `KoreForge.Jex.dll`  |  **Namespace**: `KoreForge.Jex`

---

## `Jex` Class

Stateless JSON transform engine. Thread-safe; create one instance and use it as a singleton.

```csharp
namespace KoreForge.Jex;

public sealed class Jex
{
    public Jex();

    /// Apply a Jex transform expression to a JSON input string.
    /// Returns the transformed result as a JSON string.
    /// Throws JexException on invalid transform or input.
    public string Transform(string transformJson, string inputJson);

    /// Apply a transform to a pre-parsed JsonDocument input.
    public string Transform(string transformJson, System.Text.Json.JsonDocument inputDoc);

    /// Apply one transform to multiple input documents.
    /// Processes inputs in declaration order; not parallelised internally.
    public IEnumerable<string> TransformMany(string transformJson, IEnumerable<string> inputJsonDocuments);
}
```

---

## `JexException` Class

Thrown by `Jex.Transform` when the expression cannot be evaluated.

```csharp
namespace KoreForge.Jex;

public sealed class JexException : Exception
{
    /// The expression fragment that caused the failure, if determinable.
    public string? Expression { get; }

    /// The path within the input document where evaluation failed, if applicable.
    public string? InputPath { get; }
}
```

**Common causes**:

| Condition | Exception message prefix |
|-----------|--------------------------|
| Malformed transform JSON | `"Transform JSON is not valid:"` |
| Malformed input JSON | `"Input JSON is not valid:"` |
| Undefined path (non-null-safe) | `"Path not found:"` |
| Type mismatch in arithmetic | `"Cannot apply operator"` |
| Unsupported expression key | `"Unknown Jex key:"` |

---

## DI Integration

```csharp
// Register as singleton (recommended)
builder.Services.AddSingleton<Jex>();

// Or use the extension method
builder.Services.AddJex();
```

---

## Expression Key Summary

| Key | Syntax | Description |
|-----|--------|-------------|
| Path reference | `"$in.a.b.c"` | Read nested field from input |
| Array index | `"$in.list[0]"` | Read indexed element |
| String interpolation | `"Hello $in.name!"` | Embed path in string literal |
| Comparison | `"$in.age >= 18"` | Boolean expression |
| Arithmetic | `"$in.price * 1.2"` | Numeric expression |
| Conditional | `{ "$if", "$then", "$else" }` | Ternary branch |
| Spread | `{ "$spread": "$in.obj", ... }` | Merge sub-object fields into output |
| Map | `{ "$map", "$as", "$body" }` | Project array elements |
| Filter | `{ "$filter", "$as", "$where" }` | Filter array elements |
| Coalesce | `{ "$coalesce": [...] }` | First non-null value |
| Literal | Any non-`$` value | Emitted verbatim (string, number, bool, array, object) |

See [../Introduction/04-JEX-DSL.md](../Introduction/04-JEX-DSL.md) for full syntax examples.
