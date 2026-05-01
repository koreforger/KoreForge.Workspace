# KoreForge.Json — API Reference

> Package: `KoreForge.Json` · Assemblies: `KF.Json`, `KF.Json.Jex`

Zero KoreForge dependencies.

## `JsonMaterializer`

```csharp
public static class JsonMaterializer
{
    /// Expand escaped JSON strings in token.
    /// Returns a new tree — the original token is not mutated.
    public static JToken Expand(JToken token, JsonMaterializerOptions options)
}
```

## `JsonMaterializerOptions`

```csharp
public sealed class JsonMaterializerOptions
{
    /// Maximum recursion depth (default 10).
    public int MaxDepth { get; set; } = 10;

    /// Property names known to contain escaped JSON.
    /// When set, only these fields are probed.
    /// When null or empty, ALL string values are probed.
    public IReadOnlyList<string>? FieldHints { get; set; }
}
```

## `RootPropertyClassifier`

```csharp
public sealed class RootPropertyClassifier
{
    /// Build once at startup.
    public RootPropertyClassifier(
        string[] propertyNames,
        List<KeyValuePair<int, Regex>> matches)

    /// Classify raw UTF-8 bytes.
    /// Returns:
    ///   0  = no matching root property found
    ///  -1  = property found but no regex matched
    ///  -2  = invalid/empty input or error
    ///   n  = first matching regex's int key
    public int Classify(byte[] inputData)

    /// One-shot convenience method.
    public static int Classify(
        byte[] inputData,
        string[] propertyNames,
        List<KeyValuePair<int, Regex>> matches)
}
```

## `ExpandJsonFunction` (KF.Json.Jex)

```csharp
public sealed class ExpandJsonFunction : IJexFunction
{
    public string Name => "expandJson";

    /// args[0] = path (JPath string)
    /// args[1] = maxDepth (optional, default 10)
    public JToken Invoke(JToken input, JToken[] args)
}
```

JEX usage: `expandJson($.payload, 5)`
