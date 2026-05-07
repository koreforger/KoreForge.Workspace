---
name: koreforge-time
description: "Use when working with time, dates, or clocks in a KoreForge application. Covers KoreForge.Time: ISystemClock, UtcSystemClock, LocalSystemClock, VirtualSystemClock for tests. NEVER use DateTime.Now or DateTimeOffset.UtcNow directly — always inject ISystemClock."
---

# KoreForge Time Skill

## Package

```xml
<PackageReference Include="KoreForge.Time" />
```

## Core Rule

**Never use `DateTime.Now`, `DateTime.UtcNow`, `DateTimeOffset.Now`, or `DateTimeOffset.UtcNow` directly in application code.** Always inject `ISystemClock` so tests can control time without real-clock coupling.

## ISystemClock Interface

```csharp
public interface ISystemClock
{
    DateTimeOffset UtcNow { get; }
}
```

All production and test implementations expose only `UtcNow`.

## Production Registration

```csharp
// UTC clock (standard — use this in all production apps)
builder.Services.AddSingleton<ISystemClock, UtcSystemClock>();

// Local-time clock (only when system-local time is explicitly required)
builder.Services.AddSingleton<ISystemClock, LocalSystemClock>();
```

## Injecting and Using

```csharp
public sealed class AuditService
{
    private readonly ISystemClock _clock;

    public AuditService(ISystemClock clock) => _clock = clock;

    public AuditEntry Record(string action, string actor) =>
        new AuditEntry
        {
            Action     = action,
            Actor      = actor,
            RecordedAt = _clock.UtcNow    // use this everywhere
        };
}
```

## Testing with VirtualSystemClock

`VirtualSystemClock` lets tests control the current time exactly:

```csharp
[Fact]
public async Task AuditEntry_RecordedAt_Uses_Injected_Clock()
{
    var frozenTime = new DateTimeOffset(2025, 6, 1, 12, 0, 0, TimeSpan.Zero);
    var clock = new VirtualSystemClock(frozenTime);

    var svc = new AuditService(clock);
    var entry = svc.Record("login", "alice");

    Assert.Equal(frozenTime, entry.RecordedAt);
}
```

### Advancing Time

```csharp
var clock = new VirtualSystemClock(DateTimeOffset.UtcNow);

// Advance by a fixed amount
clock.Advance(TimeSpan.FromHours(2));

// Set to a specific point
clock.Set(new DateTimeOffset(2026, 1, 1, 0, 0, 0, TimeSpan.Zero));
```

## Checklist

- [ ] `KoreForge.Time` in `Directory.Packages.props` + `.csproj`
- [ ] `AddSingleton<ISystemClock, UtcSystemClock>()` in production DI setup
- [ ] `ISystemClock` injected everywhere a timestamp is needed
- [ ] Zero occurrences of `DateTime.Now`, `DateTime.UtcNow`, `DateTimeOffset.UtcNow` as inline calls in production code
- [ ] Tests use `VirtualSystemClock` — never depend on wall clock
