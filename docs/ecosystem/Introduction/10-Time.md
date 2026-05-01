# KoreForge.Time

| | |
|---|---|
| **Package** | `KoreForge.Time` |
| **Namespace** | `KF.Time` |
| **Source** | `KoreForge.Time/src/KF.Time/` |
| **Tests** | `KoreForge.Time/tst/KF.Time.Tests/` |
| **Dependencies** | None |

## Problem

Production code that calls `DateTime.Now` or `DateTimeOffset.UtcNow` directly is untestable. You cannot write a deterministic test that asserts "this cache entry expires in 5 minutes" when the clock advances unpredictably between assertions. You also cannot reproduce time-dependent bugs.

## Solution

KoreForge.Time provides `ISystemClock` — an interface with a single `Now` property that returns `DateTimeOffset`. Three implementations ship:

- `UtcSystemClock` — wraps `DateTimeOffset.UtcNow`. Use in production for UTC-based systems.
- `LocalSystemClock` — wraps `DateTimeOffset.Now`. Use when local time zone matters.
- `VirtualSystemClock` — a manually-controlled clock for tests. You set the time, advance it, and assert against it.

## Compromises

- One more interface to inject instead of calling `DateTime.Now` directly.
- `VirtualSystemClock` prevents backward time travel by design — calling `Advance()` with a negative span throws. This protects against accidental test setup errors but means you cannot simulate clock drift.

## Installation

```bash
dotnet add package KoreForge.Time
```

## DI Registration

```csharp
// Production — UTC clock
builder.Services.AddSingleton<ISystemClock, UtcSystemClock>();

// Production — local time zone clock
builder.Services.AddSingleton<ISystemClock, LocalSystemClock>();
```

## Configuration

No configuration options. The clock is stateless.

## API Reference

### `ISystemClock`

```csharp
public interface ISystemClock
{
    DateTimeOffset Now { get; }
}
```

### `UtcSystemClock`

Returns `DateTimeOffset.UtcNow`. Suitable for all server-side code.

### `LocalSystemClock`

Returns `DateTimeOffset.Now` in the host machine's time zone.

### `VirtualSystemClock`

```csharp
public class VirtualSystemClock : ISystemClock
{
    public VirtualSystemClock(DateTimeOffset? startTime = null);
    public DateTimeOffset Now { get; }
    public void Advance(TimeSpan duration);    // duration must be non-negative
    public void Set(DateTimeOffset time);      // must not be before current Now
}
```

## Examples

### Production usage

```csharp
public class CacheService(ISystemClock clock)
{
    public bool IsExpired(DateTimeOffset cachedAt, TimeSpan ttl)
        => clock.Now - cachedAt > ttl;
}
```

### Test usage

```csharp
[Fact]
public void IsExpired_AfterTtl_ReturnsTrue()
{
    var clock = new VirtualSystemClock(DateTimeOffset.Parse("2025-01-01T00:00:00Z"));
    var service = new CacheService(clock);

    var cachedAt = clock.Now;
    clock.Advance(TimeSpan.FromMinutes(6));

    Assert.True(service.IsExpired(cachedAt, TimeSpan.FromMinutes(5)));
}
```
