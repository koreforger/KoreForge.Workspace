# KoreForge.Json

| | |
|---|---|
| **Package** | `KoreForge.Json` |
| **Namespace** | `KoreForge.Json` |
| **Source** | `KoreForge.Json/src/KF.Json/` |
| **Tests** | `KoreForge.Json/tst/KF.Json.Tests/` |
| **Dependencies** | None |

## Problem

Two recurring JSON problems in message-processing systems:

1. **Escaped JSON.** JSON payloads frequently arrive with nested JSON encoded as escaped strings (e.g., a Kafka message body where the `payload` field is `"{\"orderId\":123}"`). Consumer code must detect these, unescape them, parse the inner JSON, and reintegrate it into the document tree. This is tedious, error-prone, and done repeatedly across services.

2. **Message routing.** High-throughput systems receive heterogeneous JSON messages on a single topic and need to route them by inspecting a root property (e.g., `eventType`). Parsing the full document just to read one field is wasteful. A zero-allocation UTF-8 scan is much cheaper.

## Solution

KoreForge.Json provides two focused utilities:

- **`JsonMaterializer`** — recursively expands escaped JSON strings into their parsed object form. Accepts an optional `MaxDepth` to prevent infinite recursion and optional `FieldHints` to limit which fields are expanded.
- **`RootPropertyClassifier`** — scans raw UTF-8 bytes for a root-level property and matches its value against a set of regex patterns. Returns a numeric route ID. Zero allocation on the hot path.

Both are also available as JEX bridge functions (`expandJson()` for use inside JEX scripts).

## Compromises

- `JsonMaterializer` must parse and re-serialize, so deeply nested escaped payloads incur proportional overhead.
- `RootPropertyClassifier` only inspects root-level properties — it cannot route based on nested fields.

## Installation

```bash
dotnet add package KoreForge.Json
```

## DI Registration

No DI registration required. Both classes are stateless and can be used directly.

## Configuration

### JsonMaterializer

```csharp
var options = new JsonMaterializerOptions
{
    MaxDepth = 10,                       // Maximum recursion depth (default: 10)
    FieldHints = ["payload", "body"]     // Only expand these fields (null = expand all)
};
```

### RootPropertyClassifier

Configured at construction time:

```csharp
var classifier = new RootPropertyClassifier(
    propertyNames: ["eventType", "source"],
    matches: new List<KeyValuePair<int, Regex>>
    {
        new(1, new Regex("^order\\.")),
        new(2, new Regex("^payment\\.")),
        new(0, new Regex(".*"))         // default route
    }
);
```

## API Reference

### `JsonMaterializer`

```csharp
public static class JsonMaterializer
{
    // Expand all escaped JSON strings in the input
    public static string Expand(string json);
    public static string Expand(string json, JsonMaterializerOptions options);
}
```

### `RootPropertyClassifier`

```csharp
public class RootPropertyClassifier
{
    public RootPropertyClassifier(string[] propertyNames, List<KeyValuePair<int, Regex>> matches);

    // Classify raw UTF-8 bytes — zero allocation on hot path
    public int Classify(ReadOnlySpan<byte> utf8Json);
}
```

### `ExpandJsonFunction` (JEX bridge)

In a JEX script:

```
{
  "expanded": "expandJson($in.payload, 5)"
}
```

## Examples

### Expanding escaped JSON

```csharp
string input = """{"payload":"{\"orderId\":123,\"items\":[{\"sku\":\"A1\"}]}"}""";
string expanded = JsonMaterializer.Expand(input);
// Result: {"payload":{"orderId":123,"items":[{"sku":"A1"}]}}
```

### Routing messages by type

```csharp
var classifier = new RootPropertyClassifier(
    propertyNames: ["eventType"],
    matches: new List<KeyValuePair<int, Regex>>
    {
        new(1, new Regex("^order")),
        new(2, new Regex("^payment")),
    }
);

byte[] message = Encoding.UTF8.GetBytes("""{"eventType":"order.created","data":{}}""");
int route = classifier.Classify(message);
// route == 1
```
