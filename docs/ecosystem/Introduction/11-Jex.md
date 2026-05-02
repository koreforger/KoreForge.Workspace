# KoreForge.Jex

| | |
|---|---|
| **Package** | `KoreForge.Jex` |
| **Namespace** | `KoreForge.Jex` |
| **Source** | `KoreForge.Jex/src/KoreForge.Jex/` |
| **Tests** | `KoreForge.Jex/tst/KoreForge.Jex.Tests/` |
| **Dependencies** | None |

## Problem

Enterprise systems process millions of JSON messages daily. Each message needs to be transformed — fields renamed, nested objects flattened, arrays filtered, escaped JSON strings expanded. Doing this in C# means writing hundreds of lines of `JsonDocument` traversal code per message type. When the schema changes, the C# code changes. When a new field mapping is needed, a developer must modify, test, build, and deploy.

## Solution

JEX (JSON Expression Language) is a purpose-built DSL for JSON-to-JSON transformation. A JEX script defines the output structure declaratively: each key maps to an output field, and values are JEX expressions that extract, combine, or compute values from the input. Scripts are text files that can be authored, tested, and deployed independently of the application.

JEX is compiled once and executed many times. The runtime uses System.Text.Json internally. The language is intentionally limited — no I/O, no side effects, no external service calls. A JEX script is a pure function: JSON in, JSON out.

## Compromises

- JEX is a new language to learn. It is simpler than JSONata or jq, but it is still a DSL.
- The language is deliberately limited. You cannot make HTTP calls, write to disk, or generate random values from a JEX script. This is by design — safety and determinism are non-negotiable.
- Complex multi-step transformations may be harder to debug than equivalent C# code because the intermediate state is not visible in a standard debugger (use the VS Code preview panel instead).

## Installation

```bash
dotnet add package KoreForge.Jex
```

## DI Registration

```csharp
builder.Services.AddJex();
```

Or use directly without DI:

```csharp
var jex = new Jex();
```

## Configuration

No configuration options. JEX is stateless.

## API Reference

### `Jex` class

```csharp
public class Jex
{
    // Transform a single JSON input using a JEX script
    public string Transform(string transform, string inputJson);
    public string Transform(string transform, JsonDocument inputDoc);

    // Transform multiple inputs using the same script
    public IEnumerable<string> TransformMany(string transform, IEnumerable<string> inputs);
}
```

### `JexException`

Thrown when a script contains syntax errors or a runtime error occurs during transformation.

## Expression Syntax

| Syntax | Purpose | Example |
|--------|---------|---------|
| `$in.path.to.field` | Field access | `$in.customer.name` |
| `$in.items[0].name` | Array index | `$in.orders[0].total` |
| `"Hello $in.name"` | String interpolation | `"Order #$in.id"` |
| `$in.age >= 18` | Boolean expression | `$in.total > 100` |
| `$in.subtotal * 1.2` | Arithmetic | `$in.price * $in.qty` |
| `$if / $then / $else` | Conditional | see examples |
| `$spread` | Object projection | Copies all fields |
| `$map` | Array mapping | Transform each element |
| `$filter` | Array filter | Select matching elements |
| `$coalesce` | Null coalescing | First non-null value |

## Examples

### Simple field mapping

```
// transform.jex
{
  "fullName": "$in.first_name + ' ' + $in.last_name",
  "email": "$in.contact.email",
  "isActive": "$in.status == 'active'"
}
```

### Conditional logic

```
{
  "tier": "$if $in.total > 1000 $then 'gold' $else 'standard'"
}
```

### Array transformation

```
{
  "orderIds": "$map $in.orders => $item.id",
  "expensiveOrders": "$filter $in.orders => $item.total > 100"
}
```

### With metadata

```csharp
var jex = new Jex();
string result = jex.Transform(script, input);
```

## See Also

- [11-Jex-Cli.md](11-Jex-Cli.md) — Command-line interface for JEX
- [12-Jex-VSCode.md](12-Jex-VSCode.md) — VS Code extension with preview panel
- [13-Jex-LanguageServer.md](13-Jex-LanguageServer.md) — LSP for editor integration
- `KoreForge.Jex/doc/Specification.md` — Full language specification
