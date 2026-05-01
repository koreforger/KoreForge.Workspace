# KF.Jex.LanguageServer — JEX Language Server Protocol

| | |
|---|---|
| **Package** | `KF.Jex.LanguageServer` |
| **Source** | `KF.Jex.LanguageServer/src/` |
| **Tests** | `KF.Jex.LanguageServer/tst/` |
| **Protocol** | Language Server Protocol (LSP) over stdio |
| **Dependencies** | KoreForge.Jex, OmniSharp.Extensions.LanguageServer |

## Problem

Editor integrations for a custom DSL like JEX need a standardized protocol to provide diagnostics, completions, and hover information. Implementing these features separately for each editor (VS Code, Rider, Vim) duplicates effort.

## Solution

The JEX Language Server implements the Language Server Protocol (LSP), which is supported by most modern editors. It runs as a separate process communicating over stdio. The VS Code extension bundles and launches it automatically, but it can also be used standalone with any LSP-compatible editor.

## Compromises

- Requires .NET 10 runtime on the developer machine.
- Runs as a separate process — adds memory overhead compared to an in-process extension.

## Building

```powershell
cd KF.Jex.LanguageServer
.\scr\build-rebuild.ps1         # Build
.\scr\build-test.ps1          # Run tests
```

## Architecture

```
VS Code ←── stdio ──→ KF.Jex.LanguageServer
                           │
                           ├── TextDocumentSyncHandler (tracks open files)
                           ├── DiagnosticsHandler (syntax errors)
                           ├── CompletionHandler (autocomplete)
                           └── HoverHandler (tooltip info)
```

## Standalone Usage

For editors other than VS Code, start the language server manually:

```bash
dotnet run --project KF.Jex.LanguageServer/src/KF.Jex.LanguageServer.csproj
```

The server communicates over stdin/stdout using the LSP JSON-RPC protocol.

## See Also

- [11-Jex.md](11-Jex.md) — JEX library reference
- [11b-Jex-VSCode.md](11b-Jex-VSCode.md) — VS Code extension that bundles this server


