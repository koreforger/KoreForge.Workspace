---
name: koreforge-json
description: "Use when classifying incoming JSON messages by shape or materializing/expanding JSON tokens in a KoreForge application. Covers KoreForge.Json: RootPropertyClassifier, JsonMaterializer.Expand, classifier configuration, and classification result usage."
---

# KoreForge Json Skill

## Package

```xml
<PackageReference Include="KoreForge.Json" />
```

## Message Classification — RootPropertyClassifier

Use `RootPropertyClassifier` to determine the type of an incoming JSON message without deserializing the full payload. It inspects root property names and matches them to registered message types.

### Build Once, Classify Many

Build the classifier at startup — it is thread-safe and reuse is required for performance:

```csharp
// Build at startup (DI singleton)
public static class JsonClassifierSetup
{
    public static IServiceCollection AddJsonClassifier(this IServiceCollection services)
    {
        var classifier = new RootPropertyClassifier()
            .Register<OrderCreatedEvent>("orderId", "orderDate", "customerId")
            .Register<PaymentReceivedEvent>("paymentId", "amount", "currency")
            .Register<ShipmentEvent>("trackingNumber", "carrier");

        services.AddSingleton(classifier);
        return services;
    }
}
```

### Classify a Message

```csharp
public sealed class KafkaMessageRouter
{
    private readonly RootPropertyClassifier _classifier;

    public KafkaMessageRouter(RootPropertyClassifier classifier) => _classifier = classifier;

    public void Route(ReadOnlySpan<byte> messageBytes)
    {
        var result = _classifier.Classify(messageBytes);

        switch (result.MessageType)
        {
            case Type t when t == typeof(OrderCreatedEvent):
                HandleOrderCreated(messageBytes);
                break;
            case Type t when t == typeof(PaymentReceivedEvent):
                HandlePaymentReceived(messageBytes);
                break;
            case null:
                // Unknown message type — no registered type matched
                break;
        }
    }
}
```

`Classify` accepts `ReadOnlySpan<byte>` (UTF-8 JSON) and returns a `ClassificationResult`:

```csharp
public sealed class ClassificationResult
{
    public Type? MessageType { get; }   // null if no match
    public int PropertyCount { get; }   // number of root props scanned
    public bool IsAmbiguous { get; }    // multiple types matched
}
```

### Classification Strategy Options

```csharp
var classifier = new RootPropertyClassifier(new ClassifierOptions
{
    // How many root properties to scan before giving up
    MaxPropertiesScanned = 32,    // default

    // Require ALL registered properties to match (default is ANY)
    MatchMode = ClassificationMatchMode.Any,

    // Case-sensitive property name matching
    CaseSensitive = false    // default
})
    .Register<OrderCreatedEvent>("orderId", "customerId");
```

## JSON Materializer — Expand

Use `JsonMaterializer.Expand` to deserialize a `JsonElement` or `JsonToken` fragment into a strongly-typed object:

```csharp
using KoreForge.Json;

// Expand a JsonElement
OrderCreatedEvent order = JsonMaterializer.Expand<OrderCreatedEvent>(
    jsonElement,
    new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

// Expand bytes directly
OrderCreatedEvent order2 = JsonMaterializer.Expand<OrderCreatedEvent>(
    utf8Bytes,
    JsonSerializerOptions.Default);
```

`Expand` differs from `JsonSerializer.Deserialize` in that it handles partial documents and nested token fragments correctly — use it when deserializing already-parsed tokens from inside a larger document.

## Typical Pipeline Pattern

```csharp
// 1. Classify incoming raw bytes
var classification = _classifier.Classify(rawBytes);
if (classification.MessageType is null || classification.IsAmbiguous)
{
    _logger.Unknown.Message.LogWarning("Unrecognised message — skipping.");
    return;
}

// 2. Materialize to the identified type
if (classification.MessageType == typeof(OrderCreatedEvent))
{
    var evt = JsonMaterializer.Expand<OrderCreatedEvent>(rawBytes, _options);
    await _handler.HandleAsync(evt, ct);
}
```

## Checklist

- [ ] `KoreForge.Json` in `Directory.Packages.props` + `.csproj`
- [ ] `RootPropertyClassifier` built once at startup and registered as singleton
- [ ] `Register<T>(params string[] propertyNames)` called for each message type
- [ ] `Classify(bytes)` used on hot path — no allocation overhead
- [ ] `JsonMaterializer.Expand<T>` used for token-level deserialization
- [ ] `ClassificationResult.IsAmbiguous` checked when multiple types share property names
