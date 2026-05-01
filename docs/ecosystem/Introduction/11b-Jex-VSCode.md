# KF.Jex.VSCode — VS Code Extension

| | |
|---|---|
| **Extension** | `KF.Jex.VSCode` |
| **Source** | `KF.Jex.VSCode/` |
| **Marketplace** | (not yet published) |
| **Requirements** | VS Code 1.85+, .NET 10 Runtime |

## Problem

Writing JEX scripts in a plain text editor provides no feedback until you run the CLI. Syntax errors are discovered at execution time. There is no autocomplete for JEX expressions, no inline documentation, and no way to see the transform result without switching to a terminal.

## Solution

The VS Code extension provides full language support for `.jex` files: syntax highlighting via TextMate grammar, real-time diagnostics from the Language Server, code completion, hover information, and an interactive preview panel that shows the transformation result live as you type.

## Compromises

- Requires .NET 10 runtime for the Language Server process.
- The preview panel re-executes the full transform on every save — large scripts with large inputs may show a brief delay.

## Installation

Install from the VS Code Extensions marketplace or from a `.vsix` file:

```bash
code --install-extension kf-jex-vscode-0.0.1.vsix
```

## Features

| Feature | Description |
|---------|-------------|
| Syntax highlighting | Full TextMate grammar for JEX keywords, expressions, strings, comments |
| Language Server | Real-time syntax error diagnostics, code completion, hover info |
| Script runner | Execute the current `.jex` file directly from the editor |
| Interactive preview | Side-by-side input/output panel with auto-run on save |
| Snippets | `let`, `set`, `if`, `foreach`, `func` |

## Commands

| Command | Shortcut | Description |
|---------|----------|-------------|
| JEX: Run Script | `Ctrl+Shift+R` | Execute the current script and show output |
| JEX: Run Script with Input... | — | Run with a custom input file (file picker) |
| JEX: Show Preview Panel | `Ctrl+Shift+P` | Open the interactive input/output preview |
| JEX: Create Input File | — | Create a `.input.json` companion file |
| JEX: Show Output | — | Show the JEX output channel |

## Configuration

Settings in VS Code `settings.json`:

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `jex.languageServer.enabled` | boolean | `true` | Enable the JEX Language Server |
| `jex.languageServer.path` | string | bundled | Custom path to Language Server binary |
| `jex.cli.path` | string | bundled | Custom path to JEX CLI binary |
| `jex.preview.autoRun` | boolean | `true` | Auto-run transform when script/input is saved |

## File Conventions

The extension follows the same input file convention as the CLI:

| Script | Auto-discovered input |
|--------|----------------------|
| `transform.jex` | `transform.input.json` |

## See Also

- [11-Jex.md](11-Jex.md) — JEX library reference
- [11a-Jex-Cli.md](11a-Jex-Cli.md) — JEX CLI tool
- [11c-Jex-LanguageServer.md](11c-Jex-LanguageServer.md) — Language Server internals
