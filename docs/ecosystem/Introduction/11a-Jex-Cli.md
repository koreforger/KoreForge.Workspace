# KF.Jex.Cli — JEX Command-Line Interface

| | |
|---|---|
| **Tool** | `jex` (standalone executable) |
| **Source** | `KF.Jex.Cli/src/` |
| **Type** | .NET tool / standalone binary |
| **Dependencies** | KoreForge.Jex |

## Problem

JEX scripts need to be tested and iterated on outside of a running application. Waiting for a build-deploy cycle to verify a JSON transformation is slow and discourages experimentation.

## Solution

The JEX CLI is a command-line tool that executes JEX scripts directly from the terminal. It reads a `.jex` script file, auto-discovers or accepts an input JSON file, and writes the transformed output to stdout or a file. Watch mode re-runs the transform whenever the script or input changes.

## Compromises

- Requires .NET 10 runtime installed (unless using the self-contained build).
- Watch mode uses filesystem polling, not native file watchers — there may be a short delay on some platforms.

## Installation

### Build from source

```powershell
cd KF.Jex.Cli
.\scr\build-rebuild.ps1
```

### Standalone publish

```bash
dotnet publish -c Release -r win-x64 --self-contained
```

## Usage

### NAME

`jex` — execute a JEX transformation script

### SYNOPSIS

```
jex <script.jex> [--input <file>] [--output <file>] [--format <fmt>] [--meta <file>] [--watch]
```

### OPTIONS

| Option | Description | Default |
|--------|-------------|---------|
| `<script.jex>` | Path to JEX script file | Required |
| `--input <file>` | Path to input JSON file | Auto-discovered (see below) |
| `--output <file>` | Write result to file instead of stdout | stdout |
| `--format json` | Compact JSON output | `json` |
| `--format pretty` | Pretty-printed JSON | |
| `--format detailed` | Metadata + output + variables + timing | |
| `--meta <file>` | Metadata JSON accessible via `$meta` | None |
| `--watch` | Re-run on file changes | Off |

### INPUT FILE CONVENTION

If `--input` is not specified, the CLI looks for a companion file named `{script-name}.input.json` in the same directory as the script.

| Script file | Auto-discovered input |
|------------|----------------------|
| `transform.jex` | `transform.input.json` |
| `orders/flatten.jex` | `orders/flatten.input.json` |

### EXAMPLES

```bash
# Run with auto-discovered input
jex transform.jex

# Explicit input file
jex transform.jex --input data.json

# Pretty output
jex transform.jex --format pretty

# Write to file
jex transform.jex --output result.json

# Watch mode — re-run on any change
jex transform.jex --watch

# With metadata (accessible as $meta in script)
jex transform.jex --meta config.json
```

### METADATA

When `--meta` is provided, the metadata JSON is available in the script via `$meta`:

```
// In the JEX script
%let env = jp1($meta, "$.environment");
```

### EXIT CODES

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Script error (syntax or runtime) |
| 2 | File not found |

## See Also

- [11-Jex.md](11-Jex.md) — JEX library reference
- [12-Jex-VSCode.md](12-Jex-VSCode.md) — VS Code extension


