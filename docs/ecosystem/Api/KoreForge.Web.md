# KoreForge.Web — API Reference

**Package**: `KoreForge.Web`  |  **Namespace**: `KoreForge.Web`

---

## Registration

```csharp
// Full registration (authorization + API framework)
builder.Services.AddKoreForgeWeb(Action<KoreForgeWebOptions>? configure = null);
```

### `KoreForgeWebOptions` Class

```csharp
namespace KoreForge.Web;

public sealed class KoreForgeWebOptions
{
    /// Wrap all endpoint responses in a { success, data, error } envelope. Default: true.
    public bool EnableResponseEnvelopes { get; set; }

    /// Map KoreForgeException subtypes to HTTP status codes. Default: true.
    public bool EnableProblemDetails { get; set; }
}
```

---

## Authorization

### `AddKoreForgeAuthorization`

```csharp
namespace KoreForge.Web.Authorization;

// Extension on IServiceCollection
builder.Services.AddKoreForgeAuthorization(Action<KoreForgeAuthorizationOptions> configure);
```

### `KoreForgeAuthorizationOptions` Class

```csharp
public sealed class KoreForgeAuthorizationOptions
{
    /// Add a named authorization policy.
    public KoreForgeAuthorizationOptions AddPolicy(string name, Action<AuthorizationPolicyBuilder> build);
}
```

### `ICurrentUser` Interface

Abstracts the caller's identity for testability.

```csharp
namespace KoreForge.Web.Authorization;

public interface ICurrentUser
{
    /// The authenticated user's unique identifier (sub claim).
    string UserId { get; }

    /// The tenant identifier (tenant_id claim), or null if not present.
    string? TenantId { get; }

    /// All roles assigned to the current user.
    IEnumerable<string> Roles { get; }

    /// Returns true if the user has the specified claim with the given value.
    bool HasClaim(string claimType, string claimValue);

    /// Returns true if the user is in the given role.
    bool IsInRole(string role);
}
```

### Registration

```csharp
// Registers ICurrentUser backed by HttpContext.User
builder.Services.AddKoreForgeCurrentUser();
```

### `RequireResourceOwner` Extension

```csharp
namespace KoreForge.Web.Authorization;

// Extension on IEndpointConventionBuilder
endpoint.RequireResourceOwner(Func<HttpContext, string?> resourceIdExtractor);
```

Returns HTTP 403 if the resource ID extracted from the request does not match `ICurrentUser.UserId`.

---

## REST API Framework

### `MapKoreForgeEndpoints`

```csharp
namespace KoreForge.Web;

// Extension on IEndpointRouteBuilder
app.MapKoreForgeEndpoints(Action<IKoreForgeEndpointBuilder> configure);
```

### `IKoreForgeEndpointBuilder` Interface

```csharp
namespace KoreForge.Web;

public interface IKoreForgeEndpointBuilder
{
    IEndpointConventionBuilder Get<TRequest, TResponse>(
        string pattern,
        Delegate handler);

    IEndpointConventionBuilder Post<TRequest, TResponse>(
        string pattern,
        Delegate handler);

    IEndpointConventionBuilder Put<TRequest, TResponse>(
        string pattern,
        Delegate handler);

    IEndpointConventionBuilder Delete<TRequest>(
        string pattern,
        Delegate handler);

    IEndpointConventionBuilder Patch<TRequest, TResponse>(
        string pattern,
        Delegate handler);
}
```

---

## Response Envelope

All responses from `MapKoreForgeEndpoints` handlers use this envelope when `EnableResponseEnvelopes = true`:

```csharp
namespace KoreForge.Web;

public sealed class ApiResponse<T>
{
    public bool   Success { get; init; }
    public T?     Data    { get; init; }
    public ApiError? Error { get; init; }
}

public sealed class ApiError
{
    public string          Code    { get; init; }
    public string          Message { get; init; }
    public IList<string>?  Details { get; init; }
}
```

---

## Validation

### `IValidatable` Interface

```csharp
namespace KoreForge.Web;

public interface IValidatable
{
    ValidationResult Validate();
}
```

### `ValidationResult` Class

```csharp
namespace KoreForge.Web;

public sealed class ValidationResult
{
    public bool   IsValid  { get; }
    public string? Code    { get; }
    public string? Message { get; }
    public IReadOnlyList<string> Details { get; }

    public static ValidationResult Ok();
    public static ValidationResult Fail(string code, string message, params string[] details);
}
```

---

## Exception Mapping

`AddKoreForgeWebExceptionHandling()` maps:

| Exception Type | HTTP Status |
|----------------|-------------|
| `NotFoundException` | 404 Not Found |
| `ValidationException` | 422 Unprocessable Entity |
| `AuthorizationException` | 403 Forbidden |
| `ConflictException` | 409 Conflict |
| `KoreForgeException` (base) | 500 Internal Server Error |

```csharp
// Extension on IServiceCollection
builder.Services.AddKoreForgeWebExceptionHandling();
```

---

## `KoreForgeException` Hierarchy

```csharp
namespace KoreForge.Web;

public class KoreForgeException : Exception
{
    public string ErrorCode { get; }
    public KoreForgeException(string errorCode, string message);
    public KoreForgeException(string errorCode, string message, Exception inner);
}

public class NotFoundException       : KoreForgeException { ... }
public class ValidationException     : KoreForgeException { ... }
public class AuthorizationException  : KoreForgeException { ... }
public class ConflictException       : KoreForgeException { ... }
```
